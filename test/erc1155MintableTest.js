const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

let zeroAddress = '0x0000000000000000000000000000000000000000';

const verifyTransferEvent = (tx, ids, from, to, quantities, operator) => {
  
}

describe("Mintable ERC1155", function () {
  let erc1155Mintable, erc1155MockReceiver, owner, tx
  let gasTotal = 0
  const accounts = []

  before(async () => {
    // Get Accounts
    const signers = await ethers.getSigners()
    for (let i = 0; i < 10; i++) {
      accounts.push(signers[i])
    }
    owner = accounts[0]

    // Deploy Contract
    const ERC1155Mintable = await hre.ethers.getContractFactory("ERC1155Mintable")
    erc1155Mintable = await ERC1155Mintable.deploy()
    await erc1155Mintable.deployed()
    console.log('Address of ERC1155Mintable: ' + erc1155Mintable.address)

    const ERC1155MockReceiver = await hre.ethers.getContractFactory("ERC1155MockReceiver")
    erc1155MockReceiver = await ERC1155MockReceiver.deploy()
    await erc1155MockReceiver.deployed()
    console.log('Address of Mock Receiver: ' + erc1155Mintable.address)
  })

  after(async () => {
    console.log(gasTotal)
  })

  it("Creates initial items", async () => {
    const verifyCreateTransfer = (tx, value, creator) => {
      for (let l of tx.events) {
        if (l.event === 'TransferSingle') {
          expect(l.args._operator).to.equal(creator)
          expect(l.args._from).to.equal(zeroAddress)

          if (value > 0) {
            assert(l.args._to === creator, '_to is not the creator')
            expect(l.args._value.toNumber()).to.equal(value)
          } else {
            assert(l.args._to === zeroAddress, '_to is not zeroAddress')
            expect(l.args._value).to.equal(0)
          }
          return l.args._id
        }
      }
      assert(false, 'Did not find initial Transfer event')
    }

    // let ltxMock = {
    //   logs: [{
    //     event: 'TransferSingle',
    //     args: {
    //       _operator: 1,
    //       _from: zeroAddress,
    //       _to: 1,
    //       _value: 0,
    //     }
    //   }]
    // }

    // verifyCreateTransfer(ltxMock, 0, 1)

    let hammerQuantity = 5
    let hammerUri = 'https://metadata.enjincoin.io/hammer.json'
    tx = await erc1155Mintable.create(hammerQuantity, hammerUri)
    tx = await tx.wait()
    console.log(tx)
    hammerId = verifyCreateTransfer(tx, hammerQuantity, owner.address)
  })
})
