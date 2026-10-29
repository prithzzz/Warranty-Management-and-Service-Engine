/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    // the embedding model and native DB drivers must run as plain Node packages
    serverComponentsExternalPackages: ['@xenova/transformers', 'onnxruntime-node', 'sharp', 'mysql2', 'pg']
  }
};

export default nextConfig;
