pragma solidity ^ 0.4.18;
contract EcommerceStore {
  enum ProductStatus {
    Open,
    Sold,
    Unsold
  }
  enum ProductCondition {
    New,
    Used
  }
  uint public productIndex;
  mapping(address => mapping(uint => Product)) stores;
  mapping(uint => address) productIdInStore;

  struct Bid {
    address bidder;

    uint productId;
    uint value;
    bool revealed;
  }

  struct Product {
    uint id; //产品id
    string name; //产品名字
    string category; //分类
    string imageLink; //图片hash
    string descLink; //图片描述信息的hash
    uint auctionStartTime; //开始竞标的时间
    uint auctionEndTime; // 竞标结束时间
    uint startPrice; // 拍卖价格
    address highestBidder; // 赢家的钱包地址
    uint highestBid; // 赢家竞标的价格
    uint secondHighestBid; // 第二高的这个人的地址
    uint totalBids; // 一共有多少人参与竞标
    ProductStatus status; //状态
    ProductCondition condition; // 新、旧
    mapping(address => mapping(bytes32 => Bid)) bids;
  }

  function EcommerceStore() public {
    productIndex = 0;
  }

  /*  添加产品到区块链*/
  function addProductToStore(string _name, string _category, string _imageLink, string _descLink, uint _auctionStartTime, uint _auctionEndTime, uint _startPrice, uint _productCondition) public {
    require(_auctionStartTime < _auctionEndTime);
    productIndex += 1;
    Product memory product = Product(productIndex, _name, _category, _imageLink, _descLink, _auctionStartTime, _auctionEndTime, _startPrice, 0, 0, 0, 0, ProductStatus.Open, ProductCondition(_productCondition));
    stores[msg.sender][productIndex] = product;
    productIdInStore[productIndex] = msg.sender;
  }
  /* 通过产品ID读取产品信息 */
  function getProduct(uint _productId) view public returns(uint, string, string, string, string, uint, uint, uint, ProductStatus, ProductCondition) {
    Product memory product = stores[productIdInStore[_productId]][_productId];
    return (product.id, product.name, product.category, product.imageLink, product.descLink, product.auctionStartTime, product.auctionEndTime, product.startPrice, product.status, product.condition);
  }

  function bid(uint _productId, bytes32 _bid) payable public returns(bool) {
    Product storage product = stores[productIdInStore[_productId]][_productId];
    require(now >= product.auctionStartTime);
    require(now <= product.auctionEndTime);
    require(msg.value > product.startPrice);
    require(product.bids[msg.sender][_bid].bidder == 0);
    product.bids[msg.sender][_bid] = Bid(msg.sender, _productId, msg.value, false);
    product.totalBids += 1;
    return true;
  }

  function revealBid(uint _productId, string _amount, string _secret) public {
    Product storage product = stores[productIdInStore[_productId]][_productId];
    require(now > product.auctionEndTime);
    bytes32 sealedBid = sha3(_amount, _secret);

    Bid memory bidInfo = product.bids[msg.sender][sealedBid];
    require(bidInfo.bidder > 0);
    require(bidInfo.revealed == false);

    uint refund;

    uint amount = stringToUint(_amount);

    if (bidInfo.value < amount) {

      refund = bidInfo.value;
    } else {

      if (address(product.highestBidder) == 0) {
        product.highestBidder = msg.sender;
        product.highestBid = amount;
        product.secondHighestBid = product.startPrice;
        refund = bidInfo.value - amount;
      } else {
        if (amount > product.highestBid) {
          product.secondHighestBid = product.highestBid;
          // 退款
          product.highestBidder.transfer(product.highestBid);
          product.highestBidder = msg.sender;
          product.highestBid = amount;
          refund = bidInfo.value - amount;
        } else if (amount > product.secondHighestBid) {
          product.secondHighestBid = amount;
          refund = amount;
        } else {
          refund = amount;
        }
      }
      if (refund > 0) {
        msg.sender.transfer(refund);
        product.bids[msg.sender][sealedBid].revealed = true;
      }
    }
  }

  function highestBidderInfo(uint _productId) view public returns(address, uint, uint) {
    Product memory product = stores[productIdInStore[_productId]][_productId];
    return (product.highestBidder, product.highestBid, product.secondHighestBid);
  }

  function totalBids(uint _productId) view public returns(uint) {
    Product memory product = stores[productIdInStore[_productId]][_productId];
    return product.totalBids;
  }

  function stringToUint(string s) pure private returns(uint) {
    bytes memory b = bytes(s);
    uint result = 0;
    for (uint i = 0; i < b.length; i++) {
      if (b[i] >= 48 && b[i] <= 57) {
        result = result * 10 + (uint(b[i]) - 48);
      }
    }
    return result;
  }
}
