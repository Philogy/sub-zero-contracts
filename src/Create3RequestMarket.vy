# SPDX-License-Identifier: AGPL-3.0-only
# pragma version 0.4.0

interface SubZeroVanityMarket:
    def mint(to: address, id: uint256, nonce: uint8): nonpayable
    def computeAddress(salt: bytes32, nonce: uint8) -> address: view

event NewRequest:
    owner: address
    unlock_delay: uint256
    relevant_bits_mask: uint160
    desired_bits: uint160
    value_added: uint256

event InitiatedUnlock:
    request_key: bytes32

event Unlocked:
    request_key: bytes32

event RequestFilled:
    request_key: bytes32


REQUEST_LOCKED: constant(uint128) = max_value(uint128)
VANITY_MARKET: public(immutable(SubZeroVanityMarket))
FULFILLER: public(immutable(address))

struct RequestKey:
    owner: address
    unlock_delay: uint256
    relevant_bits_mask: uint160
    desired_bits: uint160

struct Request:
    reward: uint128
    initiated_unlock_at: uint128

struct PackedRequest:
    packed: bytes32

_requests: HashMap[bytes32, PackedRequest]

@deploy
def __init__(market: address, fulfiller: address):
    VANITY_MARKET = SubZeroVanityMarket(market)
    FULFILLER = fulfiller

@external
@payable
def request(unlock_delay: uint256, relevant_bits_mask: uint160, desired_bits: uint160):
    key: bytes32 = self._request_key(msg.sender, unlock_delay, relevant_bits_mask, desired_bits)
    request: Request = self._unpack(self._requests[key])
    request.reward += convert(msg.value, uint128)
    request.initiated_unlock_at = REQUEST_LOCKED
    self._requests[key] = self._pack(request)

    log NewRequest(
        msg.sender,
        unlock_delay,
        relevant_bits_mask,
        desired_bits,
        msg.value
    )

@external
def initiate_unlock(unlock_delay: uint256, relevant_bits_mask: uint160, desired_bits: uint160):
    key: bytes32 = self._request_key(msg.sender, unlock_delay, relevant_bits_mask, desired_bits)
    request: Request = self._unpack(self._requests[key])
    assert request.initiated_unlock_at == REQUEST_LOCKED, "Request nonexistent or unlocked"
    request.initiated_unlock_at = convert(block.timestamp, uint128)
    self._requests[key] = self._pack(request)
    log InitiatedUnlock(key)

@external
def unlock(unlock_delay: uint256, relevant_bits_mask: uint160, desired_bits: uint160):
    key: bytes32 = self._request_key(msg.sender, unlock_delay, relevant_bits_mask, desired_bits)
    request: Request = self._unpack(self._requests[key])
    assert self._unlockable(request, unlock_delay), "Not unlockable"

    self._delete_request(key)
    log Unlocked(key)

    send(msg.sender, convert(request.reward, uint256), gas=msg.gas)

@external
def fulfill(
    requester: address,
    unlock_delay: uint256,
    relevant_bits_mask: uint160,
    desired_bits: uint160,
    id: uint256,
    nonce: uint8
):
    key: bytes32 = self._request_key(requester, unlock_delay, relevant_bits_mask, desired_bits)
    request: Request = self._unpack(self._requests[key])
    assert request.reward > 0, "Request has no reward"
    to_be_minted: address = staticcall VANITY_MARKET.computeAddress(convert(id, bytes32), nonce)
    assert self._fulfills_request(
        to_be_minted,
        relevant_bits_mask,
        desired_bits
    ), "Does not fulfill request"

    self._delete_request(key)
    log RequestFilled(key)
    extcall VANITY_MARKET.mint(requester, id, nonce)
    send(FULFILLER, convert(request.reward, uint256), gas=msg.gas)

@view
@external
def get_request(
    owner: address,
    unlock_delay: uint256,
    relevant_bits_mask: uint160,
    desired_bits: uint160
) -> Request:
    return self._unpack(
        self._requests[self._request_key(
            owner,
            unlock_delay,
            relevant_bits_mask,
            desired_bits
        )]
    )

def _delete_request(key: bytes32):
    self._requests[key] = PackedRequest(packed = empty(bytes32))

@pure
def _pack(request: Request) -> PackedRequest:
    return PackedRequest(packed=convert(
        concat(
            convert(request.reward, bytes16),
            convert(request.initiated_unlock_at, bytes16)
        ),
        bytes32
    ))

@pure
def _unpack(request: PackedRequest) -> Request:
    return Request(
        reward = convert(slice(request.packed, 0, 16), uint128),
        initiated_unlock_at = convert(slice(request.packed, 16, 16), uint128),
    )

@pure
def _request_key(
    owner: address,
    unlock_delay: uint256,
    relevant_bits_mask: uint160,
    desired_bits: uint160
) -> bytes32:
    return keccak256(abi_encode(
        RequestKey(
            owner = owner,
            unlock_delay = unlock_delay,
            relevant_bits_mask = relevant_bits_mask,
            desired_bits = desired_bits
        )
    ))

@view
def _unlockable(request: Request, unlock_delay: uint256) -> bool:
    return convert(request.initiated_unlock_at, uint256) + unlock_delay <= block.timestamp\
        and request.reward > 0

@pure
def _fulfills_request(to_be_minted: address, relevant_bits_mask: uint160, desired_bits: uint160) -> bool:
    addr: uint256 = convert(to_be_minted, uint256)
    mask: uint256 = convert(relevant_bits_mask, uint256)
    desired: uint256 = convert(desired_bits, uint256)
    return addr & mask == desired
