import { JsonRpcProvider } from "ethers";

import BadgeCollection from "@/contracts/BadgeCollection.sol/BadgeCollection.json";
import { Contract } from "ethers";

export class BadgeCollectionService {
  provider: JsonRpcProvider;

  constructor(provider: JsonRpcProvider) {
    this.provider = provider;
  }

  async getBadgeUri(collectionAddress: string, badgeId: string): Promise<string> {
    const contract = new Contract(collectionAddress, BadgeCollection.abi, this.provider);

    console.log(BigInt(badgeId));
    console.log(contract.getFunction('uri'));

    return contract.getFunction('uri')(BigInt(badgeId));
  }
}
