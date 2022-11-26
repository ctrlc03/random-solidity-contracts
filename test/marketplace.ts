import { expect } from "chai";
import { ethers } from "hardhat";
import { EscrowNFTSale, EscrowNFTSale__factory, MockERC20, MockERC20__factory, MockERC721, MockERC721__factory } from "../typechain-types";
import { Signer, BigNumber, constants } from 'ethers';

const orderPrice = BigNumber.from(1000000000).mul(BigNumber.from(10).pow(18))
let nextNftId = 2

const createOrder = async (
  contract: EscrowNFTSale,
  nft: MockERC721, 
  user: Signer, 
  erc20Address: string, 
  userAddress: string
  ) => {
    await nft.connect(user).mint(userAddress, nextNftId)
    await nft.connect(user).approve(contract.address, nextNftId)
    
    await contract.connect(user).createOrder(
      nft.address,
      nextNftId,
      60 * 60 * 25,
      orderPrice,
      erc20Address,
      constants.AddressZero
    )

    nextNftId++
}

let factory: EscrowNFTSale__factory
let contract: EscrowNFTSale

let user1: Signer
let user2: Signer
let user1Address: string 
let user2Address: string 

let nftFactory: MockERC721__factory
let nft: MockERC721

let erc20Factory: MockERC20__factory
let erc20_1: MockERC20
let erc20_2: MockERC20

describe("Escrow NFT", function () {
  
  this.beforeAll(async () => {
    factory = await ethers.getContractFactory('EscrowNFTSale')
    contract = await factory.deploy();

    [user1, user2] = await ethers.getSigners()
    user1Address = await user1.getAddress()
    user2Address = await user2.getAddress()

    nftFactory = await ethers.getContractFactory('MockERC721')
    nft = await nftFactory.deploy();
    erc20Factory = await ethers.getContractFactory('MockERC20')
    erc20_1 = await erc20Factory.deploy();
    erc20_2 = await erc20Factory.deploy();

    await erc20_1.connect(user1).transfer(user2Address, orderPrice.mul(5))
    await erc20_2.connect(user1).transfer(user2Address, orderPrice.mul(5))
  })

  it('creates an order', async () => {
    await nft.connect(user1).mint(user1Address, nextNftId)
    await nft.connect(user1).approve(contract.address, nextNftId)

    await contract.connect(user1).createOrder(
      nft.address,
      nextNftId,
      60 * 60 * 25,
      orderPrice,
      erc20_1.address,
      constants.AddressZero
    )

    nextNftId++
  })

  it('emits an event when creating an order', async () => {
    await nft.connect(user1).mint(user1Address, nextNftId)
    await nft.connect(user1).approve(contract.address, nextNftId)

    const tx = await contract.connect(user1).createOrder(
      nft.address,
      nextNftId,
      60 * 60 * 25,
      orderPrice,
      erc20_1.address,
      constants.AddressZero
    )

    nextNftId++

    const receipt = await tx.wait()
    expect(receipt.events).to.not.be.null

    if (receipt.events) {
      if (receipt.events[1].args) {
        expect(receipt.events[1].args[0].toString()).to.be.eq('1')
      }
    }
  })

  it('gets the order', async () => {
    await createOrder(contract, nft, user1, erc20_1.address, user1Address)

    const order = await contract.getOrder(0)

    expect(order['seller']).to.be.eq(user1Address)
  })

  it('fulfills an order', async () => {
    await createOrder(contract, nft, user1, erc20_1.address, user1Address)

    const orderId = (await contract.nextOrderId()).sub(1).toString()

    await erc20_1.connect(user2).approve(contract.address, orderPrice)

    const tx = await contract.connect(user2).fulfillOrder(orderId)
    const receipt = await tx.wait()

    expect(receipt.events).to.not.be.null

    if (receipt.events) {
      if (receipt.events[1].args) {
        expect(receipt.events[1].args[0].toString()).to.be.eq(orderId)
      }
    }
  })

  it('cannot fulfill own order', async () => {
    await createOrder(contract, nft, user1, erc20_1.address, user1Address)

    const orderId = (await contract.nextOrderId()).sub(1).toString()

    await erc20_1.connect(user2).approve(contract.address, orderPrice)

    await expect(contract.connect(user1).fulfillOrder(orderId)).to.be.revertedWith(
      'Cannot fulfill your own order'
    )
  })

  it('cannot cancel an order after it has been fulfilled', async () => {
    await createOrder(contract, nft, user1, erc20_1.address, user1Address)

    const orderId = (await contract.nextOrderId()).sub(1).toString()

    await erc20_1.connect(user2).approve(contract.address, orderPrice)

    const tx = await contract.connect(user2).fulfillOrder(orderId)
    const receipt = await tx.wait()

    expect(receipt.events).to.not.be.null

    if (receipt.events) {
      if (receipt.events[1].args) {
        expect(receipt.events[1].args[0].toString()).to.be.eq(orderId)
      }
    }

    await expect(contract.connect(user1).cancelOrder(orderId)).to.be.revertedWith(
      'This order was already fullfilled'
    )
  })

});
