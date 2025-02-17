// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

//  ==========  External imports    ==========
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ERC20Token is AccessControl, ERC20Permit {
    // Create a new role identifier for the minter role
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) ERC20Permit(_symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Mints a new token
     * @param account address to send the minted tokens to
     * @param amount amount of tokens to mint
     */
    function mint(address account, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        _mint(account, amount);
        return true;
    }

    /**
     * @dev Burns a  token
     * @param account address to burn tokens from
     * @param amount amount of tokens to burn
     */
    function burn(address account, uint256 amount) external returns (bool) {
        if (account != msg.sender) {
            _spendAllowance(msg.sender, account, amount);
        }
        _burn(account, amount);
        return true;
    }
}
