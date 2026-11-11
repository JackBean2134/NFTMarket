// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyERC20WithTransferAndCall is ERC20 {
    event TransferAndCall(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        bytes data
    );

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply
    ) ERC20(name_, symbol_) {
        _mint(msg.sender, initialSupply);
    }

    function transferAndCall(
        address to,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        //零地址检查
        require(to != address(0), "transfer to zero address");
        bool success = transfer(to, amount);
        require(success, "ERC20: transfer failed");
        emit TransferAndCall(msg.sender, to, amount, data);
        (bool callSuccess, ) = to.call(
            abi.encodeWithSignature(
                "tokensReceived(address,uint256,bytes)",
                msg.sender,
                amount,
                data
            )
        );
        require(callSuccess, "tokensReceived callback failed");
        return true;
    }
}
