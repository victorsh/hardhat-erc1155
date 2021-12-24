const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
import expectThrow from './helpers/expectThrow'

let erc1155Mintable, erc1155MockReceiver, owner, tx
let gasTotal = 0
const accounts = []
let zeroAddress = '0x0000000000000000000000000000000000000000';
let idSet = []
let hammerId, swordId, maceId
let quantities = [1, 1, 1]

const recordGasUsed = (_tx, _label) => {
  gasUsedTotal += _tx.receipt.gasUsed
  asUsedRecords.push(String(_label + ' \| GasUsed: ' + _tx.receipt.gasUsed).padStart(60))
}

const printGasUsed = () => {
  console.log('------------------------------------------------------------');
  for (let i = 0; i < gasUsedRecords.length; ++i) {
      console.log(gasUsedRecords[i]);
  }
  console.log(String("Total: " + gasUsedTotal).padStart(60));
  console.log('------------------------------------------------------------');
}

const verifyURI = (tx, uri, id) => {
  for (let l of tx.events) {
    if (l.event === 'URI') {
      expect(l.args._id).to.equal(id)
      expect(l.args._value).to.equal(uri)
      return;
    }
  }
}

const verifyTransferEvent = (tx, id, from, to, quantity, operator) => {
  let eventCount = 0
  for (let l of tx.events) {
    if (l.event === 'TransferSingle') {
      assert(l.args._operator === operator, "Operator mis-match");
      assert(l.args._from === from, "from mis-match");
      assert(l.args._to === to, "to mis-match");
      assert(l.args._id.eq(id), "id mis-match");
      assert(l.args._value.toNumber() === quantity, "quantity mis-match");
      eventCount += 1;
    }
  }
  if (eventCount === 0) {
    assert(false, 'Missing Transfer Event')
  } else {
    assert(eventCount === 1, 'Unexpected number of Transfer events')
  }
}

const testSafeTransferFrom = async (operator, from, to, id, quantity, data, gasMessage='testSafeTransferFrom') => {
  let preBalanceFrom = ethers.BigNumber.from(await erc1155Mintable.balanceOf(from.address, id))
  let preBalanceTo = ethers.BigNumber.from(await erc1155Mintable.balanceOf(to.address, id))

  tx = await erc1155Mintable.connect(operator).safeTransferFrom(from.address, to.address, id, quantity, data)
  tx = await tx.wait()
  verifyTransferEvent(tx, id, from.address, to.address, quantity, operator.address)

  let postBalanceFrom = ethers.BigNumber.from(await erc1155Mintable.balanceOf(from.address, id))
  let postBalanceTo = ethers.BigNumber.from(await erc1155Mintable.balanceOf(to.address, id))

  if (from.address !== to.address) {
    assert.strictEqual(preBalanceFrom.sub(quantity).toNumber(), postBalanceFrom.toNumber())
    assert.strictEqual(preBalanceTo.add(quantity).toNumber(), postBalanceTo.toNumber())
  } else {
    assert.strictEqual(preBalanceFrom.toNumber(), postBalanceFrom.toNumber())
  }
}

const verifyTransferEvents = (tx, ids, from, to, quantities, operator) => {
  let totalIdCount = 0
  for (let l of tx.events) {
    if (l.event === 'TransferBatch' && l.args._operator === operator && l.args._from === from && l.args._to === to) {
      for (let j = 0; j < ids.length; j++) {
        let id = ethers.BigNumber.from(l.args._ids[j])
        let value = ethers.BigNumber.from(l.args._values[j])
        if (id === ids[j] && value === quantities[j]) {
          ++totalIdCount
        }
      }
    }
  }

  assert(totalIdCount === ids.length, 'Unexpected number of Transfer events found ' + totalIdCount + ' expected ' + ids.length)
}

describe("Mintable ERC1155", function () {
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

    let hammerQuantity = 5
    let hammerUri = 'https://metadata.enjincoin.io/hammer.json'
    tx = await erc1155Mintable.create(hammerQuantity, hammerUri)
    tx = await tx.wait()
    hammerId = verifyCreateTransfer(tx, hammerQuantity, owner.address)
    idSet.push(hammerId)
    verifyURI(tx, hammerUri, hammerId)

    let swordQuantity = 200
    let swordUri = 'https://metadata.enjincoin.io/sword.json'
    tx = await erc1155Mintable.create(swordQuantity, swordUri)
    tx = await tx.wait()
    swordId = verifyCreateTransfer(tx, swordQuantity, owner.address)
    idSet.push(swordId)
    verifyURI(tx, swordUri, swordId)

    let maceQuantity = 1000000
    let maceUri = 'https://metadata.enjincoin.io/mace.json'
    tx = await erc1155Mintable.create(maceQuantity, maceUri)
    tx = await tx.wait()
    maceId = verifyCreateTransfer(tx, maceQuantity, owner.address)
    idSet.push(maceId)
    verifyURI(tx, maceUri, maceId)
  })

  it('safeTranferFrom throws with no balance', async () => {
    await expectThrow
  })
  it('safeTransferFrom from self with enough balance', async () => {
    await testSafeTransferFrom(owner, owner, accounts[1], hammerId, 1, ethers.utils.formatBytes32String(''))
    await testSafeTransferFrom(accounts[1], accounts[1], owner, hammerId, 1, ethers.utils.formatBytes32String(''))
  })
})
