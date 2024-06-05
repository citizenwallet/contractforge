import { Badge } from "@/state/badge/state";

export class IPFSService {
    baseUrl: string;

    constructor(baseUrl?: string) {
        this.baseUrl = baseUrl ?? "https://ipfs.io/ipfs";
    }

    async get(hash: string): Promise<Badge> {
        const response = await fetch(`${this.baseUrl}/${hash}`);
        return response.json();
    }
}