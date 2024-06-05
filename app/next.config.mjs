/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "ipfs.internal.citizenwallet.xyz",
        port: "",
        pathname: "/*",
      },
    ],
  },
};

export default nextConfig;
