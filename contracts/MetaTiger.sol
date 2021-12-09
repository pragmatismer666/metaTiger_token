pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IRouter {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint amountIn,
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
    ) external;
}


contract MetaTIGR is ERC20, Ownable {
    using SafeMath for uint256;
    bool public SalesTax;
    bool public AntiWhale;

    //Current issuer is the address in the document
    address constant public _issuer = 0x8e07bD3C4b24eaa38Ddd47Fa35DE5CcADabc0EF6;
    address constant public Burn = 0x2FD200e22874630a344CbD94b4128755c9ca7a90;
    address constant public LiquidityToken = 0x2FD200e22874630a344CbD94b4128755c9ca7a90;
    address constant public LiquidityBNB = 0xd0965E573C7F8F8C3fC610FfD099d5Db8621500F;
    address constant public MarketingToken = 0x13Bb3f83ec8bccC5F9A3AA56797920A2acE45feF;
    address constant public MarketingBNB = 0xCb46D46570000106E927c8afEdD55c6C6C8ca0a8;
    address constant public RewardsToken = 0xDB706C2B7206f843385d72ba319da563B13Be283;
    address constant public RewardsBNB = 0xC314C8Ae03561cF2B5B631370Ca53F4E7C3171d3;
    address constant public CharityToken = 0x14F0b08bbb05Bb3fb4b36540DBC5d18701FC1832;
    address constant public CharityBNB = 0x2749cf03120f859d00E7E3602e93b1dBd4D714AE;
    address constant public Router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

    IRouter pancakeRouter = IRouter(Router);

    address constant public BNB = 0xB8c77482e45F1F44dE1745F52C74426C631bDD52;
    address public pair;

    mapping(address => bool) public whiteList;

    constructor() ERC20("Meta Tiger", "TIGR") {
        // 1,000,000,001 Total Supply
        ERC20._mint(_issuer, 1 * (10 **18));
        ERC20._mint(Burn, 2250000000 * (10 **18));
        ERC20._mint(LiquidityToken, 7000000000 * (10 **18));
        ERC20._mint(MarketingToken, 250000000 * (10 **18));
        ERC20._mint(RewardsToken, 250000000 * (10 **18));
        ERC20._mint(CharityToken, 250000000 * (10 **18));
        

        (address token0, address token1) = address(this) < BNB? (address(this), BNB) : (BNB, address(this));

        pair = address(uint160(uint256(bytes32(keccak256(abi.encodePacked(
               hex'ff',
               0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73, // factory
               keccak256(abi.encodePacked(token0, token1)),
               hex'00fb7f630766e6a796048ea87d01acd3068e8ff67d078148a3fa3f4a84f69bd5' // init code hash
        ))))));

        whiteList[_issuer] = true;
        whiteList[Burn] = true;
        whiteList[LiquidityToken] = true;
        whiteList[MarketingToken] = true;
        whiteList[RewardsToken] = true;
        whiteList[CharityToken] = true;


    }

    function setWhiteList(address _who, bool _value) external onlyOwner {
        whiteList[_who] = _value;
    }

    function burn(uint256 _amount) external {
        ERC20._burn(msg.sender, _amount);
    }

    function changeSalesTax() external onlyOwner {
        SalesTax = !SalesTax;
    }

    function changeAntiWhale() external onlyOwner {
        AntiWhale = !AntiWhale;
    }

    // make tax for transfers, make anti whale
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override virtual {
        // no tax and anti whale for whiteList
        if(whiteList[from]) {
            return;
        }

        // no fee for mint and burn action
        if(from == address(0) || to == address(0)) {
            return;
        }

        // apply commission sanctions 10%
        if (SalesTax) {
            uint256 _percent = amount.div(100);
            if (_percent == 0) {
                return;
            }
            // means buy on pancake router
            if(from == pair) {
                ERC20._mint(address(this), _percent);
                swapToBNB(MarketingBNB, _percent);
            }
            // all other transfers
            else {
                // 3% Burned
                ERC20._mint(Burn, _percent.mul(3));
                // 2% to liquidity (1% Token & 1% BNB)
                ERC20._mint(LiquidityToken, _percent);
                
                
                // 2% to marketing (0.5% Token & 1.5% BNB)
                ERC20._mint(MarketingToken, _percent.div(2));
                
                
                // 1.5% to charity (0.25% Token & 1.25% BNB)
                ERC20._mint(CharityToken, _percent.mul(25).div(100));
                
                
                // 1.5% to rewards (0.25% Token & 1.25% BNB)
                ERC20._mint(RewardsToken, _percent.mul(25).div(100));

                // All tokens will be converted to BNB minted at once to reduce gas usage
                ERC20._mint(address(this), _percent + _percent.mul(15).div(10) + _percent.mul(125).div(100) + _percent.mul(125).div(100));

                // BNBs distrubuted to addresses
                swapToBNB(LiquidityBNB, _percent);
                swapToBNB(MarketingBNB, _percent.mul(15).div(10));
                swapToBNB(CharityBNB, _percent.mul(125).div(100));
                swapToBNB(RewardsBNB, _percent.mul(125).div(100));
                ERC20._burn(to, _percent.mul(10));
            }
        }
        // because admins can have more than limit
        if(whiteList[to]) {
            return;
        }
        // apply anti whale sanctions
        if(AntiWhale) {
            // No more than 1% of total supply
            require(ERC20.balanceOf(to) <= ERC20.totalSupply().div(100), "balanceExceedsLimit");
        }
    }

    //Using pancake swap to convert Token to BNB
    function swapToBNB(address to, uint amountIn) internal {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = BNB;
        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
        amountIn,
        0,
        path,
        to,
        block.timestamp + 60 minutes
        );
    }
}
