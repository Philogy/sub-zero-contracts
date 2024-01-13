// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IERC1155Receiver} from "./IERC1155Receiver.sol";

/// @notice Minimalist and gas efficient ERC1155 implementation optimized for non-fungible IDs.
/// @author Forked from solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155Unique {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TransferSingle(
        address indexed operator, address indexed from, address indexed to, uint256 id, uint256 amount
    );

    event TransferBatch(
        address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] amounts
    );

    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    event URI(string value, uint256 indexed id);

    /*//////////////////////////////////////////////////////////////
    //                           ERRORS                           //
    //////////////////////////////////////////////////////////////*/

    error NotAuthorized();

    error InsufficientBalance();

    error UnsafeRecipient();

    error LengthMismatch();

    /*//////////////////////////////////////////////////////////////
                             ERC1155 STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => mapping(address => bool)) public isApprovedForAll;

    /*//////////////////////////////////////////////////////////////
                             METADATA LOGIC
    //////////////////////////////////////////////////////////////*/

    function uri(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                              ERC1155 LOGIC
    //////////////////////////////////////////////////////////////*/

    function setApprovalForAll(address operator, bool approved) public virtual {
        isApprovedForAll[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data)
        public
        virtual
    {
        if (msg.sender != from && !isApprovedForAll[from][msg.sender]) revert NotAuthorized();
        uint256 balance = balanceOf(from, id);
        if (amount > balance) revert InsufficientBalance();
        if (balance == 1) _setOwnerOf(id, to);

        emit TransferSingle(msg.sender, from, to, id, amount);
        _doReceiveCheck(to, from, id, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual {
        if (msg.sender != from && !isApprovedForAll[from][msg.sender]) revert NotAuthorized();

        uint256 id;
        uint256 idsLength = ids.length;

        unchecked {
            for (uint256 i = 0; i < idsLength; ++i) {
                id = ids[i];
                uint256 balance = balanceOf(from, id);
                if (amounts[i] > balance) revert InsufficientBalance();
                if (balance == 1) _setOwnerOf(id, to);
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);
        _doBatchReceiveCheck(from, to, ids, amounts, data);
    }

    function ownerOf(uint256 id) public view virtual returns (address);

    function balanceOf(address owner, uint256 id) public view returns (uint256) {
        return ownerOf(id) == owner ? 1 : 0;
    }

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        public
        view
        virtual
        returns (uint256[] memory balances)
    {
        uint256 idsLength = ids.length;
        if (owners.length != idsLength) revert LengthMismatch();

        balances = new uint256[](idsLength);

        unchecked {
            for (uint256 i = 0; i < idsLength; ++i) {
                balances[i] = balanceOf(owners[i], ids[i]);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165 Interface ID for ERC165
            || interfaceId == 0xd9b67a26 // ERC165 Interface ID for ERC1155
            || interfaceId == 0x0e89341c; // ERC165 Interface ID for ERC1155MetadataURI
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id, bytes memory data) internal virtual {
        ownerOf[id] = to;

        emit TransferSingle(msg.sender, address(0), to, id, 1);
        _doReceiveCheck(address(0), to, id, data);
    }

    function _batchMint(address to, uint256[] memory ids, bytes memory data) internal virtual {
        uint256 idsLength = ids.length; // Saves MLOADs.

        uint256[] memory amounts = new uint256[](idsLength);

        unchecked {
            for (uint256 i = 0; i < idsLength; ++i) {
                ownerOf[ids[i]] = to;
                amounts[i] = 1;
            }
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);
        _doBatchReceiveCheck(address(0), to, ids, amounts, data);
    }

    function _burn(uint256 id) internal virtual {
        address owner = ownerOf[id];
        _setOwnerOf(id, address(0));

        emit TransferSingle(msg.sender, owner, address(0), id, 1);
    }

    function _setOwnerOf(uint256 id, address owner) internal virtual;

    function _doReceiveCheck(address from, address to, uint256 id, bytes memory data) internal {
        if (
            to.code.length == 0
                ? to == address(0)
                : IERC1155Receiver(to).onERC1155Received(msg.sender, from, id, 1, data)
                    != IERC1155Receiver.onERC1155Received.selector
        ) revert UnsafeRecipient();
    }

    function _doBatchReceiveCheck(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        if (
            to.code.length == 0
                ? to == address(0)
                : IERC1155Receiver(to).onERC1155BatchReceived(msg.sender, from, ids, amounts, data)
                    != IERC1155Receiver.onERC1155Received.selector
        ) revert UnsafeRecipient();
    }
}
