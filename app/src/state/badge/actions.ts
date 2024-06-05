import { JsonRpcProvider } from "ethers";
import { BadgeStore, useBadgeStore } from "./state";
import { useMemo } from "react";
import { IPFSService } from "@/services/ipfs";
import { BadgeCollectionService } from "@/services/badgeCollection";
import { StoreApi, UseBoundStore } from "zustand";

class BadgeActions {
  store: BadgeStore;
  ipfs: IPFSService;
  rpcProvider: JsonRpcProvider;
  badeCollectionService: BadgeCollectionService;

  constructor(store: () => BadgeStore, rpcUrl: string, ipfsUrl: string) {
    this.store = store();
    this.rpcProvider = new JsonRpcProvider(rpcUrl);
    this.ipfs = new IPFSService(ipfsUrl);
    this.badeCollectionService = new BadgeCollectionService(this.rpcProvider);
  }

  async fetchBadge(collectionAddress: string, badgeId: string) {
    try {
      this.store.badgeRequest();

      const ipfsHash = await this.badeCollectionService.getBadgeUri(
        collectionAddress,
        badgeId
      );

      console.log("ipfsHash", ipfsHash);

      const badge = await this.ipfs.get(ipfsHash);

      console.log("badge", badge);

      badge.image = `${this.ipfs.baseUrl}/${badge.image.replace(
        "ipfs://",
        ""
      )}`;
      badge.image_medium = `${this.ipfs.baseUrl}/${badge.image_medium.replace(
        "ipfs://",
        ""
      )}`;
      badge.image_small = `${this.ipfs.baseUrl}/${badge.image_small.replace(
        "ipfs://",
        ""
      )}`;

      this.store.badgeRequestSuccess(badge);
    } catch (error: any) {
      console.error(error);
      this.store.badgeRequestFailure(error.message);
    }
  }
}

export const useBadge = (
  rpcUrl: string,
  ipfsUrl: string
): [UseBoundStore<StoreApi<BadgeStore>>, BadgeActions] => {
  const store = useBadgeStore;
  const actions = useMemo(
    () => new BadgeActions(() => store.getState(), rpcUrl, ipfsUrl),
    [store, rpcUrl, ipfsUrl]
  );

  return [store, actions];
};
