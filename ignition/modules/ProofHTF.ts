import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("ProofModule", (m) => {
  const proof = m.contract("ProofHTF");

  m.call(proof, "incBy", [5n]);


  return { proof };
});
