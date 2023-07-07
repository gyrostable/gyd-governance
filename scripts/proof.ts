import { utils } from "ethers";
import { promises } from "fs";
import path from "path";

const { open, readFile } = promises;

const defaultInFile = path.join(path.dirname(__dirname), "data", "discord_contributors.csv")
const defaultOutFile = path.join(path.dirname(__dirname), "data", "proofs-discord.json")

type Element = { owner: string, multiplier: BigInt }
type OutputDatum = {
  owner: string,
  multiplier: string,
  proof: string[]
};


function traverseMerkle(
  elements: Element[],
  process: ((leaves: string[]) => void) | undefined = undefined,
): string {
  let leaves = elements.map((a) => utils.solidityKeccak256(["address", "uint128"], [a.owner, a.multiplier]));
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

function generateRoot(elements: Element[]): string {
  return traverseMerkle(elements);
}

function generateProof(line: Element, lines: Element[]): string[] {
  const leafIndex = lines.findIndex((l) => l.owner === line.owner);
  if (leafIndex === -1) {
    throw new Error("Account not found");
  }
  let nodeIndex = leafIndex;
  const hashes: string[] = [];

  const process = (leaves: string[]) => {
    const delta = nodeIndex % 2 === 0 ? 1 : -1;
    const hash = leaves[nodeIndex+delta]
    hashes.push(hash);
    nodeIndex = Math.floor(nodeIndex / 2);
  };

  traverseMerkle(lines, process);

  return hashes;
}

async function generateProofs(inFile: string, outFile: string): Promise<void> {
  const ownerData = await readFile(inFile, "utf-8");
  const lines = ownerData.trim().split("\n")
  const parse = (line: string) => {
   const parsed = line.split(",");
   return { owner: parsed[0], multiplier: BigInt(parseInt(parsed[1])) };
  }
  const data = lines.map(parse);

  const root = generateRoot(data);
  const proofs: OutputDatum[] = [];
  for (const datum of data) {
    const proof = generateProof(datum, data);
    let result = validateProof(datum.owner, datum.multiplier, proof, root);
    if (!result) {
	    throw "invalid proof"
    }
    proofs.push({
      owner: datum.owner,
      multiplier: datum.multiplier.toString(),
      proof
    });
  }

  const out = await open(outFile, 'w');
  out.writeFile(JSON.stringify({ root: generateRoot(data), proofs: proofs}));
}

function validateProof(owner: string, multiplier: BigInt, proof: string[], root: string): boolean {
  let node = utils.solidityKeccak256(["address", "uint128"], [owner, multiplier]);
  for (const proofElement of proof) {
      let [left, right] = [node, proofElement];
      if (left > right) [left, right] = [right, left];
      node = utils.solidityKeccak256(["bytes32", "bytes32"], [left, right]);
  }
  return node == root
}


generateProofs(defaultInFile, defaultOutFile);
