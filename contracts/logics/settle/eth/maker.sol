// SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import { DSMath } from "../../../libs/safeMath.sol";

interface VaultDataInterface {

    struct VaultData {
        uint id;
        address owner;
        string colType;
        uint collateral;
        uint art;
        uint debt;
        uint liquidatedCol;
        uint borrowRate;
        uint colPrice;
        uint liquidationRatio;
        address vaultAddress;
    }

    function getVaultById(uint id) external view returns (VaultData memory);

}

interface DSAInterface {
    function cast(address[] calldata _targets, bytes[] calldata _datas, address _origin) external payable;
}

contract LogicOne is DSMath {

    function getOriginAddress() private pure returns(address) {
        return 0xB7fA44c2E964B6EB24893f7082Ecc08c8d0c0F87; // DSA address
    }
    
    function getMcdAddresses() public pure returns (address) {
        return 0xF23196DF1C440345DE07feFbe556a5eF0dcD29F0;
    }

    function getInstaMakerResolver() public pure returns (address) {
        return 0x0A7008B38E7015F8C36A49eEbc32513ECA8801E5;
    }

    function getMakerConnectAddress() public pure returns (address) {
        return 0x6c4E4D4aB22cAB08b8498a3A232D92609e8b2d62;
    }

    function getDsaAddress() private pure returns(address) {
        return address(0); // DSA address
    }

    function vaultId() private pure returns(uint) {
        return 0; // vault ID
    }

    function checkMakerVault() private view {
        VaultDataInterface.VaultData memory vaultData = VaultDataInterface(getInstaMakerResolver()).getVaultById(vaultId());
        uint col = vaultData.collateral;
        uint debt = vaultData.debt;
        uint price = vaultData.colPrice / 10 ** 9; // making 18 decimal
        // uint liquidation = vaultData.liqInk / 10 ** 9; // making 18 decimal
        uint currentRatio = wdiv(wmul(col, price), debt);
        require(200 * 10 ** 18 < currentRatio, "position-risky"); // ratio should be less than 50% (should we keep it 60%?)
    }

    function depositAndBorrow(uint depositAmt, uint borrowAmt) public {
        address[] memory _targets = new address[](2);
        bytes[] memory _data = new bytes[](2);
        _targets[0] = getMakerConnectAddress();
        _data[0] = abi.encodeWithSignature("deposit(uint256,uint256,uint256,uint256)", vaultId(), depositAmt, uint(0), uint(0));
        _targets[1] = getMakerConnectAddress();
        _data[1] = abi.encodeWithSignature("borrow(uint256,uint256,uint256,uint256)", vaultId(), borrowAmt, uint(0), uint(0));
        DSAInterface(getDsaAddress()).cast(_targets, _data, getOriginAddress());
        checkMakerVault();
    }

    function paybackAndWithdraw(uint withdrawAmt, uint paybackAmt) public {
        address[] memory _targets = new address[](2);
        bytes[] memory _data = new bytes[](2);
        _targets[0] = getMakerConnectAddress();
        _data[0] = abi.encodeWithSignature("payback(uint256,uint256,uint256,uint256)", vaultId(), paybackAmt, uint(0), uint(0));
        _targets[1] = getMakerConnectAddress();
        _data[1] = abi.encodeWithSignature("withdraw(uint256,uint256,uint256,uint256)", vaultId(), withdrawAmt, uint(0), uint(0));
        DSAInterface(getDsaAddress()).cast(_targets, _data, getOriginAddress());
        checkMakerVault();
    }

    receive() external payable {}

}
