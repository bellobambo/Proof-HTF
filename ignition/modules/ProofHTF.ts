import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ProofModule", (m) => {
  const proof = m.contract("ProofHTF");


  return { proof };
});
