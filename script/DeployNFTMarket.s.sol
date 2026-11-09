// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MyERC20WithTransferAndCall.sol";
import "../src/NFTMarket.sol";

contract DeployNFTMarket is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MyERC20WithTransferAndCall paymentToken = new MyERC20WithTransferAndCall(
                "PayToken",
                "PAY",
                10000 * 1e18
            );
        console.log("PaymentToken:", address(paymentToken));

        address feeRecipient = msg.sender; // 部署者作为手续费接收地址
        uint256 feeRate = 50;
        NFTMarket market = new NFTMarket(
            address(paymentToken),
            feeRecipient,
            feeRate
        );
        console.log("NFTMarket:", address(market));

        vm.stopBroadcast();
    }
}
