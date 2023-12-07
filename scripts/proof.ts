import { utils } from "ethers";
import fs from "fs/promises";
import path from "path";

const defaultInFile = path.join(path.dirname(__dirname), "data", "discord_contributors.csv");
const defaultOutFile = path.join(path.dirname(__dirname), "data", "proofs-discord.json");

function scale(value: number | bigint, decimals: number = 18): bigint {
  if (typeof value === "bigint") return value * BigInt(10 ** decimals);
  return BigInt(Math.floor(value * 10 ** decimals));
}

class Element {
  owner: string;
  multiplier: bigint;

  constructor(owner: string, multiplier: bigint) {
    this.owner = owner;
    if (multiplier < 10 ** 10) {
      multiplier = scale(multiplier);
    }
    this.multiplier = multiplier;
  }

  toLeaf() {
    return utils.solidityKeccak256(["address", "uint128"], [this.owner, this.multiplier]);
  }

  toObject(): { owner: string; multiplier: string } {
    return { owner: this.owner, multiplier: this.multiplier.toString() };
  }

  static fromLine(line: string): Element {
    const [owner, multiplier] = line.split(",");
    return new Element(owner, multiplier ? BigInt(parseInt(multiplier)) : undefined);
  }
}

type OutputDatum = {
  owner: string;
  multiplier: string;
  proof: string[];
};

function traverseMerkle(elements: Element[], process: ((leaves: string[]) => void) | undefined = undefined): string {
  let leaves = elements.map((e) => e.toLeaf());
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
    const hash = leaves[nodeIndex + delta];
    hashes.push(hash);
    nodeIndex = Math.floor(nodeIndex / 2);
  };

  traverseMerkle(lines, process);

  return hashes;
}

async function generateProofs(inFile: string, outFile: string): Promise<void> {
  console.log(inFile, outFile);
  const ownerData = await fs.readFile(inFile, "utf-8");
  const lines = ownerData.trim().split("\n");
  const data = lines.map(Element.fromLine);

  const root = generateRoot(data);
  const proofs: OutputDatum[] = [];
  let i = 0;
  for (const datum of data) {
    const proof = generateProof(datum, data);
    let result = validateProof(datum, proof, root);
    if (!result) {
      console.error(i, datum);
      throw "invalid proof";
    }
    proofs.push({ ...datum.toObject(), proof });
    i++;
    if (i % 100 === 0) console.log(`${i}/${data.length}`);
  }

  const output = JSON.stringify({ root: generateRoot(data), proofs: proofs });
  await fs.writeFile(outFile, output, "utf-8");
}

function validateProof(element: Element, proof: string[], root: string): boolean {
  let node = element.toLeaf();
  for (const proofElement of proof) {
    let [left, right] = [node, proofElement];
    if (left > right) [left, right] = [right, left];
    node = utils.solidityKeccak256(["bytes32", "bytes32"], [left, right]);
  }
  return node == root;
}

const [, , inFile, outFile] = process.argv;

generateProofs(inFile || defaultInFile, outFile || defaultOutFile);
