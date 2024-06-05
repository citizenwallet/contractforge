"use client";

import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Box } from "@radix-ui/themes";

import { useBadge } from "@/state/badge/actions";
import { Section } from "@radix-ui/themes";
import { useEffect } from "react";
import Image from "next/image";

interface BadgeProps {
  rpcUrl: string;
  ipfsUrl: string;
  collectionAddress: string;
  badgeId: string;
}

export default function Badge({
  rpcUrl,
  ipfsUrl,
  collectionAddress,
  badgeId,
}: BadgeProps) {
  const [state, actions] = useBadge(rpcUrl, ipfsUrl);

  useEffect(() => {
    actions.fetchBadge(collectionAddress, badgeId);
    console.log("fetchBadge");
  }, [actions, collectionAddress, badgeId]);

  const loading = state((state) => state.loading);
  const badge = state((state) => state.badge);

  console.log('badge?.image_medium', badge?.image_medium);

  return (
    <Section>
      <Card className="max-w-sm">
        <CardHeader>
          <CardTitle>{badge?.name ?? ''}</CardTitle>
          <CardDescription>{badge?.description ?? ''}</CardDescription>
        </CardHeader>
        <CardContent className="flex flex-col items-center overflow-hidden">
          <Box
            height="200px"
            width="200px"
            className="bg-gray-200 overflow-hidden rounded-md fade-in"
          >
            {!loading && badge != null && (
              <Image
                src={badge.image_medium}
                alt="badge icon"
                height={200}
                width={200}
              />
            )}
          </Box>
          Claim Badge {badge?.image_medium} ({collectionAddress}) ({badgeId})
        </CardContent>
        <CardFooter>
          <Button>{loading ? "Loading..." : "Claim"}</Button>
        </CardFooter>
      </Card>
    </Section>
  );
}
