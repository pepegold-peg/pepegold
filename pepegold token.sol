/**
 *Submitted for verification at BscScan.com on 2025-08-08
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title PEPEGOLDToken
 * @dev BEP-20 compatible token with milestone-based token lock functionality.
 *
 * - Solidity Version: ^0.8.24
 * - 단일 파일로 구성 (import 없음)
 * - OpenZeppelin v5 스타일 기반 구조 수동 구현
 * - ERC20, Ownable, Pausable 포함
 * - AccountLock, Withdraw, Burnable, Milestone Lock 지원
 */

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract Pausable is Ownable {
    bool private _paused;
    bool public pauseFinished; 
    event Paused();
    event Unpaused();
    event PauseFinished();

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    modifier canPause() {
        require(!pauseFinished, "Pausable: pause permanently disabled");
        _;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    function pause() public onlyOwner whenNotPaused canPause {
        _paused = true;
        emit Paused();
    }

    function unpause() public onlyOwner whenPaused canPause {  
        _paused = false;
        emit Unpaused();
    }
    
        function finishPause() external onlyOwner {
        pauseFinished = true;
        emit PauseFinished();
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract ERC20 is Context, IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 private _totalSupply;

    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 initialSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        _mint(_msgSender(), initialSupply);
    }

    function totalSupply() public view override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        uint256 currentAllowance = _allowances[from][_msgSender()];
        require(currentAllowance >= amount, "ERC20: allowance exceeded");
        _approve(from, _msgSender(), currentAllowance - amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(to != address(0), "ERC20: transfer to zero");
        require(_balances[from] >= amount, "ERC20: insufficient balance");
        _balances[from] -= amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal virtual {
        require(to != address(0), "ERC20: mint to zero");
        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        require(_balances[from] >= amount, "ERC20: burn exceeds balance");
        _balances[from] -= amount;
        _totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0) && spender != address(0), "ERC20: zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}



contract PEPEGOLDToken is ERC20, Pausable {
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** 18;
    mapping(address => bool) public lockedAccounts;
    bool public withdrawingFinished;
    bool public accountLockFinished;

    struct Policy {
        uint256 kickOff;
        uint256[] periods;
        uint256[] percentages;
    }
    mapping(uint8 => Policy) public policies;
    mapping(address => mapping(uint8 => uint256)) public lockedBalances;

    event LockAccount(address indexed account);
    event UnlockAccount(address indexed account);
    event Burn(address indexed from, uint256 value);
    event Withdraw(address indexed from, address indexed to, uint256 value);
    event WithdrawFinished();
    event PolicySet(uint8 indexed id, uint256 kickoff);
    event AccountLockFinished();

    modifier notLocked(address account) {
        require(!lockedAccounts[account], "Account is locked");
        _;
    }

    modifier canWithdraw() {
        require(!withdrawingFinished, "Withdrawals disabled");
        _;
    }

    modifier canLockAccount() {
    require(!accountLockFinished, "AccountLock: permanently disabled");
    _;
    }

    constructor() ERC20("PEPE GOLD", "PEG", 18, MAX_SUPPLY) {}

    function lockAccount(address account) external onlyOwner canLockAccount {
        lockedAccounts[account] = true;
        emit LockAccount(account);
    }

    function unlockAccount(address account) external onlyOwner canLockAccount {
        lockedAccounts[account] = false;
        emit UnlockAccount(account);
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
    }

    function withdraw(address from, uint256 amount) external onlyOwner canWithdraw {
        _transfer(from, owner(), amount);
        emit Withdraw(from, owner(), amount);
    }

    function withdrawTo(address from, address to, uint256 amount) external onlyOwner canWithdraw {
        _transfer(from, to, amount);
        emit Withdraw(from, to, amount);
    }

    function finishWithdraw() external onlyOwner {
        withdrawingFinished = true;
        emit WithdrawFinished();
    }

    function finishAccountLock() external onlyOwner {
    accountLockFinished = true;
    emit AccountLockFinished();
    }

    function setPolicy(uint8 id, uint256 kickoff, uint256[] memory periods, uint256[] memory percentages) external onlyOwner {
        require(periods.length == percentages.length, "Mismatched inputs");
        delete policies[id].periods;
        delete policies[id].percentages;
        policies[id].kickOff = kickoff;
        for (uint i = 0; i < periods.length; i++) {
            policies[id].periods.push(periods[i]);
            policies[id].percentages.push(percentages[i]);
        }
        emit PolicySet(id, kickoff);
    }

    function distributeWithPolicy(address to, uint256 amount, uint8 policyId) external onlyOwner {
        _transfer(owner(), to, amount);
        lockedBalances[to][policyId] += amount;
    }

    function getLockedAmount(address user, uint8 policyId) public view returns (uint256) {
        Policy storage policy = policies[policyId];
        if (policy.kickOff == 0 || policy.kickOff > block.timestamp) {
            return lockedBalances[user][policyId];
        }
        uint256 unlockedPercent;
        for (uint i = 0; i < policy.periods.length; i++) {
            if (block.timestamp >= policy.kickOff + policy.periods[i]) {
                unlockedPercent += policy.percentages[i];
            }
        }
        if (unlockedPercent >= 100) {
            return 0;
        }
        return lockedBalances[user][policyId] * (100 - unlockedPercent) / 100;
    }

    function getAvailableBalance(address user) public view returns (uint256) {
        uint256 locked;
        for (uint8 i = 0; i < 100; i++) {
            if (lockedBalances[user][i] > 0) {
                locked += getLockedAmount(user, i);
            }
        }
        return balanceOf(user) - locked;
    }

    function transfer(address to, uint256 amount) public override whenNotPaused notLocked(msg.sender) returns (bool) {
        require(getAvailableBalance(msg.sender) >= amount, "Insufficient unlocked balance");
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override whenNotPaused notLocked(msg.sender) returns (bool) {
        require(!lockedAccounts[from], "From account is locked");
        require(getAvailableBalance(from) >= amount, "Insufficient unlocked balance");
        return super.transferFrom(from, to, amount);
    }

    function approve(address spender, uint256 amount) public override whenNotPaused notLocked(msg.sender) returns (bool) {
        return super.approve(spender, amount);
    }
}
