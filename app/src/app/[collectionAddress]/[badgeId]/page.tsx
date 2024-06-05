
import Badge from "@/containers/Badge";

interface BadgeProps {
  params: {
    collectionAddress: string;
    badgeId: string;
  };
  searchParams: {
    account: string;
  };
}

export default function Page({
  params: { collectionAddress, badgeId },
  searchParams: { account },
}: BadgeProps) {
  const rpcUrl = process.env.RPC_URL;
  const ipfsUrl = process.env.IPFS_URL;

  if (!rpcUrl || !ipfsUrl) {
    throw new Error("Missing environment variables");
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24">
      <Badge
        collectionAddress={collectionAddress}
        badgeId={badgeId}
        rpcUrl={rpcUrl}
        ipfsUrl={ipfsUrl}
      />
    </main>
  );
}
