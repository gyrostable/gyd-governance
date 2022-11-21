import { utils } from "ethers";
import { promises } from "fs";
import path from "path";

const { open, readFile, writeFile } = promises;

const defaultInFile = path.join(path.dirname(__dirname), "data", "frog_owners.csv")
const defaultOutFile = path.join(path.dirname(__dirname), "data", "proofs.json")

type Proofs = { root: string, proofs: Map<string,string[]> };

function traverseMerkle(
  accounts: string[],
  process: ((leaves: string[]) => void) | undefined = undefined,
): string {
  let leaves = accounts.map((a) => utils.solidityKeccak256(["address"], [a]));
  while (leaves.length > 1) {
    if (leaves.length % 2 === 1) {
      leaves.push(utils.solidityKeccak256([], []));
    }
    if (process) process(leaves);

    const newLeaves = [];
    for (let i = 0; i < leaves.length; i += 2) {
      let [left, right] = [leaves[i], leaves[i + 1]];
      if (left > right) [left, right] = [right, left];
      newLeaves.push(utils.solidityKeccak256(["bytes32", "bytes32"], [left, right]));
    }
    leaves = newLeaves;
  }
  return leaves[0];
}

function generateRoot(accounts: string[]): string {
  return traverseMerkle(accounts);
}

function generateProof(account: string, accounts: string[]): string[] {
  const leafIndex = accounts.findIndex((a) => a === account);
  if (leafIndex === -1) {
    throw new Error("Account not found");
  }
  let nodeIndex = leafIndex;
  const hashes: string[] = [];

  const process = (leaves: string[]) => {
    const delta = nodeIndex % 2 === 0 ? 1 : -1;
    hashes.push(leaves[nodeIndex + delta]);
    nodeIndex = Math.floor(nodeIndex / 2);
  };

  traverseMerkle(accounts, process);

  return hashes;
}

async function generateProofs(inFile: string = defaultInFile, outFile: string = defaultOutFile): Promise<void> {
  const ownerData = await readFile(inFile, "utf-8");
  const owners = ownerData.trim().split("\n");

  const root = generateRoot(owners);
  const proofs = new Map<string,string[]>();
  for (const owner of owners) {
    const proof = generateProof(owner, owners);
    let result = validateProof(owner, proof, root);
    if (!result) {
	throw "invalid proof"
    }
    proofs[owner] = proof;
  }

  const out = await open(outFile, 'w');
  out.writeFile(JSON.stringify({ root: generateRoot(owners), proofs: proofs}));
}

function validateProof(owner: string, proof: string[], root: string): boolean {
  let node = utils.solidityKeccak256(["address"], [owner]);
  for (const proofElement of proof) {
      let [left, right] = [node, proofElement];
      if (left > right) [left, right] = [right, left];
      node = utils.solidityKeccak256(["bytes32", "bytes32"], [left, right]);
  }
  return node == root
}

generateProofs();
