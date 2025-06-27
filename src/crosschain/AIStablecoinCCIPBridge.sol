// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { CCIPReceiver } from "@chainlink/contracts-ccip/applications/CCIPReceiver.sol";
import { Client } from "@chainlink/contracts-ccip/libraries/Client.sol";
import { IRouterClient } from "@chainlink/contracts-ccip/interfaces/IRouterClient.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { OwnedThreeStep } from "@solbase/auth/OwnedThreeStep.sol";

import { AIStablecoin } from "../AIStablecoin.sol";

/// @title AIStablecoinCCIPBridge - Cross-Chain Bridge for AI Stablecoin Protocol
/// @notice Enables CCIP-powered cross-chain transfers of AIUSD to Avalanche and other networks
/// @dev External bridge contract that gets vault authorization for minting/burning operations
/// @dev Main use case: Move AIUSD liquidity from Sepolia (where AI analysis happens) to Avalanche testnet
contract AIStablecoinCCIPBridge is CCIPReceiver, OwnedThreeStep {
    // =============================================================
    //                    CONSTANTS & STORAGE
    // =============================================================

    /// @notice The AI Stablecoin contract on this chain
    AIStablecoin public aiStablecoin;

    /// @notice LINK token for paying CCIP fees
    IERC20 public linkToken;

    /// @notice Router client for CCIP operations
    IRouterClient public router;

    /// @notice Mapping of supported destination chains
    mapping(uint64 => bool) public supportedChains;

    /// @notice Mapping of trusted bridge contracts on other chains
    mapping(uint64 => address) public trustedRemoteBridges;

    /// @notice Fee token type - LINK vs Native
    enum PayFeesIn {
        Native,
        LINK
    }

    // =============================================================
    //                       EVENTS & ERRORS
    // =============================================================

    event TokensBridged(
        bytes32 indexed messageId,
        uint64 indexed destinationChain,
        address indexed recipient,
        uint256 amount,
        uint256 fees
    );

    event TokensReceived(
        bytes32 indexed messageId, uint64 indexed sourceChain, address indexed recipient, uint256 amount
    );

    event ChainSupported(uint64 indexed chainSelector, bool supported);
    event TrustedRemoteSet(uint64 indexed chainSelector, address indexed remoteBridge);
    event RouterUpdated(address indexed oldRouter, address indexed newRouter);
    event LinkTokenUpdated(address indexed oldLinkToken, address indexed newLinkToken);
    event AIStablecoinUpdated(address indexed oldStablecoin, address indexed newStablecoin);

    error ChainNotSupported(uint64 chainSelector);
    error UntrustedSource(uint64 sourceChain, address sender);
    error InsufficientBalance(uint256 available, uint256 required);
    error InvalidAmount(uint256 amount);
    error InvalidAddress(address account);

    // =============================================================
    //                      CONSTRUCTOR
    // =============================================================

    /// @notice Initialize the AI Stablecoin CCIP Bridge with core dependencies
    /// @dev Sets up the bridge contract with updateable references to CCIP router, LINK token, and AI stablecoin
    /// @dev Constructor parameters are updateable via setRouter(), setLinkToken(), setAIStablecoin()
    /// @param _router Address of the Chainlink CCIP router contract for cross-chain messaging
    /// @param _linkToken Address of the LINK token contract used for paying CCIP fees (alternative to native)
    /// @param _aiStablecoin Address of the AI Stablecoin contract that this bridge will mint/burn tokens for
    constructor(address _router, address _linkToken, address _aiStablecoin)
        CCIPReceiver(_router)
        OwnedThreeStep(msg.sender)
    {
        router = IRouterClient(_router);
        linkToken = IERC20(_linkToken);
        aiStablecoin = AIStablecoin(_aiStablecoin);
    }

    // =============================================================
    //                     ACCESS CONTROL
    // =============================================================

    /// @notice Restricts function access to trusted remote bridge contracts only
    /// @dev Validates that incoming CCIP messages originate from authorized bridge contracts on specific chains
    /// @dev This prevents unauthorized minting by ensuring only trusted bridges can trigger token minting
    /// @dev Used exclusively in _ccipReceive() to validate cross-chain message authenticity
    /// @param _sourceChainSelector CCIP chain selector identifying the source blockchain
    /// @param _sender Address of the contract that sent the CCIP message on the source chain
    modifier onlyTrustedSource(uint64 _sourceChainSelector, address _sender) {
        if (trustedRemoteBridges[_sourceChainSelector] != _sender) {
            revert UntrustedSource(_sourceChainSelector, _sender);
        }
        _;
    }

    // =============================================================
    //                    MAIN BRIDGE LOGIC
    // =============================================================

    /// @notice Bridge AIUSD tokens to Avalanche testnet (or other supported chains) using CCIP burn-and-mint
    /// @dev Main feature: Move liquidity from Sepolia (AI analysis chain) to Avalanche (execution chain)
    /// @param _destinationChainSelector CCIP chain selector for destination (e.g., Avalanche Fuji:
    /// 14767482510784806043)
    /// @param _recipient Address to receive tokens on destination chain
    /// @param _amount Amount of AIUSD to bridge
    /// @param _payFeesIn Whether to pay fees in LINK or native token
    function bridgeTokens(uint64 _destinationChainSelector, address _recipient, uint256 _amount, PayFeesIn _payFeesIn)
        external
        payable
        returns (bytes32 messageId)
    {
        // Validation
        if (!supportedChains[_destinationChainSelector]) {
            revert ChainNotSupported(_destinationChainSelector);
        }
        if (_recipient == address(0)) revert InvalidAddress(_recipient);
        if (_amount == 0) revert InvalidAmount(_amount);

        uint256 userBalance = aiStablecoin.balanceOf(msg.sender);
        if (userBalance < _amount) {
            revert InsufficientBalance(userBalance, _amount);
        }

        // Burn tokens on source chain (Sepolia)
        // Note: User must approve this bridge contract first
        aiStablecoin.burnFrom(msg.sender, _amount);

        // Prepare CCIP message
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(trustedRemoteBridges[_destinationChainSelector]),
            data: abi.encode(_recipient, _amount),
            tokenAmounts: new Client.EVMTokenAmount[](0), // No native token transfer
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({ gasLimit: 200_000 })),
            feeToken: _payFeesIn == PayFeesIn.LINK ? address(linkToken) : address(0)
        });

        // Calculate and pay fees
        uint256 fees = router.getFee(_destinationChainSelector, message);

        if (_payFeesIn == PayFeesIn.LINK) {
            linkToken.transferFrom(msg.sender, address(this), fees);
            linkToken.approve(address(router), fees);
            messageId = router.ccipSend(_destinationChainSelector, message);
        } else {
            messageId = router.ccipSend{ value: fees }(_destinationChainSelector, message);
        }

        emit TokensBridged(messageId, _destinationChainSelector, _recipient, _amount, fees);
        return messageId;
    }

    /// @notice Internal function to handle incoming CCIP messages
    /// @param _any2EvmMessage The CCIP message received
    function _ccipReceive(Client.Any2EVMMessage memory _any2EvmMessage)
        internal
        override
        onlyTrustedSource(_any2EvmMessage.sourceChainSelector, abi.decode(_any2EvmMessage.sender, (address)))
    {
        // Decode message data
        (address recipient, uint256 amount) = abi.decode(_any2EvmMessage.data, (address, uint256));

        // Mint tokens on destination chain (Avalanche)
        aiStablecoin.mint(recipient, amount);

        emit TokensReceived(_any2EvmMessage.messageId, _any2EvmMessage.sourceChainSelector, recipient, amount);
    }

    // =============================================================
    //                      ADMIN FUNCTIONS
    // =============================================================

    /// @notice Update the CCIP router address (owner only)
    /// @param _newRouter New router contract address
    function setRouter(address _newRouter) external onlyOwner {
        if (_newRouter == address(0)) revert InvalidAddress(_newRouter);
        address oldRouter = address(router);
        router = IRouterClient(_newRouter);
        emit RouterUpdated(oldRouter, _newRouter);
    }

    /// @notice Update the LINK token address (owner only)
    /// @param _newLinkToken New LINK token contract address
    function setLinkToken(address _newLinkToken) external onlyOwner {
        if (_newLinkToken == address(0)) revert InvalidAddress(_newLinkToken);
        address oldLinkToken = address(linkToken);
        linkToken = IERC20(_newLinkToken);
        emit LinkTokenUpdated(oldLinkToken, _newLinkToken);
    }

    /// @notice Update the AI Stablecoin address (owner only)
    /// @param _newAIStablecoin New AI Stablecoin contract address
    function setAIStablecoin(address _newAIStablecoin) external onlyOwner {
        if (_newAIStablecoin == address(0)) revert InvalidAddress(_newAIStablecoin);
        address oldStablecoin = address(aiStablecoin);
        aiStablecoin = AIStablecoin(_newAIStablecoin);
        emit AIStablecoinUpdated(oldStablecoin, _newAIStablecoin);
    }

    /// @notice Add or remove supported destination chain
    /// @param _chainSelector CCIP chain selector
    /// @param _supported Whether chain is supported for bridging
    function setSupportedChain(uint64 _chainSelector, bool _supported) external onlyOwner {
        supportedChains[_chainSelector] = _supported;
        emit ChainSupported(_chainSelector, _supported);
    }

    /// @notice Set trusted bridge contract on remote chain
    /// @param _chainSelector CCIP chain selector for remote chain
    /// @param _remoteBridge Address of trusted bridge contract on remote chain
    function setTrustedRemote(uint64 _chainSelector, address _remoteBridge) external onlyOwner {
        if (_remoteBridge == address(0)) revert InvalidAddress(_remoteBridge);
        trustedRemoteBridges[_chainSelector] = _remoteBridge;
        emit TrustedRemoteSet(_chainSelector, _remoteBridge);
    }

    /// @notice Emergency function to withdraw stuck LINK tokens
    /// @param _amount Amount of LINK to withdraw
    function emergencyWithdrawLink(uint256 _amount) external onlyOwner {
        linkToken.transfer(owner, _amount);
    }

    /// @notice Emergency function to withdraw stuck native tokens
    function emergencyWithdrawNative() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    // =============================================================
    //                      VIEW FUNCTIONS
    // =============================================================

    /// @notice Calculate bridge fees for a given destination
    /// @param _destinationChainSelector CCIP chain selector
    /// @param _amount Amount to bridge (for gas estimation)
    /// @param _payFeesIn Fee payment method
    /// @return fees Fee amount in the specified token
    function calculateBridgeFees(uint64 _destinationChainSelector, uint256 _amount, PayFeesIn _payFeesIn)
        external
        view
        returns (uint256 fees)
    {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(trustedRemoteBridges[_destinationChainSelector]),
            data: abi.encode(msg.sender, _amount),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({ gasLimit: 200_000 })),
            feeToken: _payFeesIn == PayFeesIn.LINK ? address(linkToken) : address(0)
        });

        return router.getFee(_destinationChainSelector, message);
    }

    /// @notice Check if user has approved bridge for token spending
    /// @param _user User address to check
    /// @return allowance Current allowance amount
    function getUserAllowance(address _user) external view returns (uint256 allowance) {
        return aiStablecoin.allowance(_user, address(this));
    }

    /// @notice Get current LINK token address
    /// @return Current LINK token contract address
    function getLinkToken() external view returns (address) {
        return address(linkToken);
    }

    /// @notice Get current AI Stablecoin address
    /// @return Current AI Stablecoin contract address
    function getAIStablecoin() external view returns (address) {
        return address(aiStablecoin);
    }

    /// @notice Receive native tokens for fee payments
    receive() external payable { }
}
