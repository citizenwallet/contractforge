import { create } from "zustand";

export interface Badge {
  name: string;
  description: string;
  image: string;
  image_medium: string;
  image_small: string;
  tokenId: string;
  url: string;
  start: Date;
  end: Date;
  type: "virtual" | "in-person";
  location: {
    name: string;
    coordinates: string; // or [number, number] if coordinates are a pair of latitude and longitude
  };
}

export type BadgeStore = {
  loading: boolean;
  error: string;
  badge: Badge | null;
  badgeRequest: () => void;
  badgeRequestSuccess: (badge: Badge) => void;
  badgeRequestFailure: (error: string) => void;
};

const getInitialState = () => ({
  loading: false,
  error: "",
  badge: null,
});

export const useBadgeStore = create<BadgeStore>((set) => ({
  ...getInitialState(),
  badgeRequest: () => {
    set({ loading: true, error: "", badge: null });
  },
  badgeRequestSuccess: (badge: Badge) => {
    set({ loading: false, error: "", badge });
  },
  badgeRequestFailure: (error: string) => {
    set({ loading: false, error });
  },
}));
