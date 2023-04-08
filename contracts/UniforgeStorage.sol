// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PriceConverter.sol";

error UniforgeStorage__TransferFailed();
error UniforgeStorage__InsufficientEth();

/**
 * @title Uniforge Storage
 * @author d-carranza
 * @notice This contract verify Storage Payments in Uniforge
 * @notice emiting events that confirm the transactions.
 * @notice For more info about Uniforge, visit uniforge.io.
 * @notice Powered by dapponics.io
 */
// Verifies the storage service has been contracted by emitting an event verifying the purchase
contract UniforgeStorage is Ownable {
    using PriceConverter for uint256;

    AggregatorV3Interface private immutable priceFeed;
    uint256 private monthlyFee; // USD * 1e18
    uint256 private yearlyFee; // USD * 1e18
    mapping(address => uint256) private pinnedMonthsByUser;
    uint256 roundedDecimals; // Gwei:1e9, Szabo:1e12, Finney:1e15

    event PaymentVerified(
        uint256 indexed date,
        address indexed user,
        uint256 indexed monthsAdded
    );
    event MonthlyFeeSet(uint256 indexed monthlyFee);
    event YearlyFeeSet(uint256 indexed yearlyFee);
    event RoundedDecimalsSet(uint256 indexed roundedDecimals);

    /**
     * @dev Creates a new instance of the contract.
     * @param _owner The address of the new owner of the UniforgeStorage contract.
     * @param _priceFeed The address of the Chainlink price feed to use for ETH/USD conversion.
     * @param _monthlyFee The monthly fee in USD * 1e18.
     * @param _yearlyFee The yearly fee in USD * 1e18.
     * @param _roundedDecimals The number of decimals to round the fee amount to.
     */
    constructor(
        address _owner,
        address _priceFeed,
        uint256 _monthlyFee,
        uint256 _yearlyFee,
        uint256 _roundedDecimals
    ) {
        transferOwnership(_owner);
        priceFeed = AggregatorV3Interface(_priceFeed);
        monthlyFee = _monthlyFee;
        yearlyFee = _yearlyFee;
        roundedDecimals = _roundedDecimals;
    }

    /**
     * @dev Allows a user to pay for storage service for a specified number of months.
     * @param _amount The number of months to pay for.
     */
    function payMonths(uint256 _amount) external payable {
        if (msg.value.getConversionRate(priceFeed) < monthlyFee * _amount)
            revert UniforgeStorage__InsufficientEth();

        pinnedMonthsByUser[msg.sender] += _amount;
        emit PaymentVerified(block.timestamp, msg.sender, _amount);
    }

    /**
     * @dev Allows a user to pay for storage service for a specified number of years.
     * @param _amount The number of years to pay for.
     */
    // In the frontend clean the input from 1 to 20
    function payYears(uint256 _amount) external payable {
        if (msg.value.getConversionRate(priceFeed) < yearlyFee * _amount)
            revert UniforgeStorage__InsufficientEth();

        uint256 totalMonths = _amount * 12;
        pinnedMonthsByUser[msg.sender] += totalMonths;
        emit PaymentVerified(block.timestamp, msg.sender, totalMonths);
    }

    /**
     * @notice Owner sets the monthly storage fee in USD.
     * @param _monthlyFee The new monthly fee.
     */
    function setMonthlyFee(uint256 _monthlyFee) public onlyOwner {
        monthlyFee = _monthlyFee;

        emit MonthlyFeeSet(monthlyFee);
    }

    /**
     * @notice Owner sets the yearly storage fee in USD.
     * @param _yearlyFee The new yearly fee.
     */
    function setYearlyFee(uint256 _yearlyFee) public onlyOwner {
        yearlyFee = _yearlyFee;
        emit YearlyFeeSet(yearlyFee);
    }

    /**
     * @notice Owner sets the number of decimals to round to when calculating storage fees.
     * @param _roundedDecimals The new number of rounded decimals.
     */
    function setRoundedDecimals(uint256 _roundedDecimals) public onlyOwner {
        roundedDecimals = _roundedDecimals;
        emit RoundedDecimalsSet(roundedDecimals);
    }

    /**
     * @notice Owner withdraws the contract's balance to the owner's address.
     */
    function withdraw() public onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if (!success) {
            revert UniforgeStorage__TransferFailed();
        }
    }

    /**
     * @notice Calculates the monthly storage fee in ETH for a given number of months.
     * @param _amount The number of months to calculate the fee for.
     * @return The rounded monthly fee in ETH.
     */
    function getEthMonthlyFee(uint256 _amount) public view returns (uint256) {
        int256 ethPrice = getPriceValue();
        uint256 value = ((monthlyFee * _amount * 1e8) / uint256(ethPrice));
        uint256 rounded = ((value / roundedDecimals) + 1) * roundedDecimals;
        return rounded;
    }

    /**
     * @notice Calculates the yearly storage fee in ETH for a given number of years.
     * @param _amount The number of years to calculate the fee for.
     * @return The rounded yearly fee in ETH.
     */
    function getEthYearlyFee(uint256 _amount) public view returns (uint256) {
        int256 ethPrice = getPriceValue();
        uint256 value = ((yearlyFee * _amount * 1e8) / uint256(ethPrice));
        uint256 rounded = ((value / roundedDecimals) + 1) * roundedDecimals;
        return rounded;
    }

    /**
     * @notice Returns the monthly storage fee in USD.
     * @return The monthly fee in USD.
     */
    function getUsdMonthlyFee() public view returns (uint256) {
        return monthlyFee;
    }

    /**
     * @notice Returns the yearly storage fee in USD.
     * @return The yearly fee in USD.
     */
    function getUsdYearlyFee() public view returns (uint256) {
        return yearlyFee;
    }

    /**
     * @notice Returns the total number of months a user has paid for storage.
     * @param _user The user's address.
     * @return The total number of months the user has paid for.
     */
    function getPinnedMonthsByUser(
        address _user
    ) public view returns (uint256) {
        return pinnedMonthsByUser[_user];
    }

    /**
     * @notice Returns the latest ETH/USD exchange rate from the price oracle.
     * @return The latest ETH/USD exchange rate.
     */
    function getPriceValue() public view returns (int256) {
        (, int256 answer, , , ) = priceFeed.latestRoundData();
        return answer;
    }

    /**
     * @notice Returns the number of decimals to round to when calculating storage fees.
     * @return The number of decimals to round to.
     */
    function getRoundedDecimals() public view returns (uint256) {
        return roundedDecimals;
    }

    /**
     * @notice Returns the address of the price oracle used for calculating storage fees.
     * @return The address of the price oracle.
     */
    function getPriceFeed() public view returns (address) {
        return address(priceFeed);
    }

    /**
     * @notice Returns the version number of the price oracle.
     * @return The version number of the price oracle.
     */
    function getVersion() public view returns (uint256) {
        return priceFeed.version();
    }
}
