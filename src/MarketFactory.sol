// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Market.sol";
import "./PriceMarket.sol";
import "./MarketAMM.sol";
import "./OutcomeToken.sol";

contract MarketFactory {
    address public owner;
    address public feeRecipient;
    address public immutable USDC;
    uint256 public constant PROTOCOL_FEE_BPS = 50; // 0.50% protocol fee on trades

    address[] public allMarkets;

    event MarketCreated(
        address indexed marketAddress,
        address indexed creator,
        address targetUser,
        uint32 perpId,
        address yesToken,
        address noToken,
        address amm
    );

    event PriceMarketCreated(
        address indexed marketAddress,
        address indexed creator,
        uint32 perpId,
        uint64 strikePrice,
        address yesToken,
        address noToken,
        address amm
    );

    constructor(address _feeRecipient, address _usdc) {
        owner = msg.sender;
        feeRecipient = _feeRecipient;
        USDC = _usdc;
    }

    function createMarket(
        address _targetUser,
        uint32 _perpId,
        uint256 _endTime,
        address _positionReader,
        address _markPxReader,
        string calldata _yesTokenName,
        string calldata _yesTokenSymbol,
        string calldata _noTokenName,
        string calldata _noTokenSymbol
    ) external returns (address) {
        // 1. Deploy Outcome Tokens
        OutcomeToken yesToken = new OutcomeToken(_yesTokenName, _yesTokenSymbol);
        OutcomeToken noToken = new OutcomeToken(_noTokenName, _noTokenSymbol);

        // 2. Deploy the AMM for this market, passing in the fee recipient
        MarketAMM amm = new MarketAMM(address(yesToken), address(noToken), feeRecipient, PROTOCOL_FEE_BPS);

        // 3. Deploy the Market contract itself
        Market market = new Market(
            _targetUser,
            _perpId,
            _endTime,
            USDC,
            _positionReader,
            _markPxReader,
            address(yesToken),
            address(noToken),
            address(amm)
        );

        // 4. Grant minting/burning authority to the Market contract
        yesToken.transferMinter(address(market));
        noToken.transferMinter(address(market));

        // 5. Record the new market
        allMarkets.push(address(market));

        emit MarketCreated(
            address(market),
            msg.sender,
            _targetUser,
            _perpId,
            address(yesToken),
            address(noToken),
            address(amm)
        );

        return address(market);
    }

    function createPriceMarket(
        uint32 _perpId,
        uint256 _endTime,
        uint64 _strikePrice,
        address _markPxReader,
        string calldata _yesTokenName,
        string calldata _yesTokenSymbol,
        string calldata _noTokenName,
        string calldata _noTokenSymbol
    ) external returns (address) {
        // 1. Deploy Outcome Tokens
        OutcomeToken yesToken = new OutcomeToken(_yesTokenName, _yesTokenSymbol);
        OutcomeToken noToken = new OutcomeToken(_noTokenName, _noTokenSymbol);

        // 2. Deploy the AMM for this market, passing in the fee recipient
        MarketAMM amm = new MarketAMM(address(yesToken), address(noToken), feeRecipient, PROTOCOL_FEE_BPS);

        // 3. Deploy the PriceMarket contract itself
        PriceMarket priceMarket = new PriceMarket(
            _perpId,
            _endTime,
            _strikePrice,
            USDC,
            _markPxReader,
            address(yesToken),
            address(noToken),
            address(amm)
        );

        // 4. Grant minting/burning authority to the PriceMarket contract
        yesToken.transferMinter(address(priceMarket));
        noToken.transferMinter(address(priceMarket));

        // 5. Record the new market
        allMarkets.push(address(priceMarket));

        emit PriceMarketCreated(
            address(priceMarket),
            msg.sender,
            _perpId,
            _strikePrice,
            address(yesToken),
            address(noToken),
            address(amm)
        );

        return address(priceMarket);
    }

    function setFeeRecipient(address _newFeeRecipient) external {
        require(msg.sender == owner, "Only owner");
        feeRecipient = _newFeeRecipient;
    }
}