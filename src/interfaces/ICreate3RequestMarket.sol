// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ICreate3RequestMarket {
    event InitiatedUnlock(bytes32 request_key);
    event NewRequest(
        address owner, uint256 unlock_delay, uint160 relevant_bits_mask, uint160 desired_bits, uint256 value_added
    );
    event RequestFilled(bytes32 request_key);
    event Unlocked(bytes32 request_key);

    function FULFILLER() external view returns (address);
    function VANITY_MARKET() external view returns (address);
    function fulfill(
        address requester,
        uint256 unlock_delay,
        uint160 relevant_bits_mask,
        uint160 desired_bits,
        uint256 id,
        uint8 nonce
    ) external;
    function get_request(address owner, uint256 unlock_delay, uint160 relevant_bits_mask, uint160 desired_bits)
        external
        view
        returns (uint128, uint128);
    function initiate_unlock(uint256 unlock_delay, uint160 relevant_bits_mask, uint160 desired_bits) external;
    function request(uint256 unlock_delay, uint160 relevant_bits_mask, uint160 desired_bits) external payable;
    function unlock(uint256 unlock_delay, uint160 relevant_bits_mask, uint160 desired_bits) external;
}
