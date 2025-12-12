import { DefaultAzureCredential } from "@azure/identity";
import { AIProjectClient } from "@azure/ai-projects";

const projectEndpoint: string = process.env["AZURE_AI_PROJECT_ENDPOINT"] || "<project endpoint>";
const modelDeploymentName: string = process.env["AZURE_AI_FOUNDRY_MODEL_DEPLOYMENT_NAME"] || "<model deployment name>";
const agentName: string = process.env["AZURE_AI_FOUNDRY_AGENT_NAME"] || "<agent name>";

async function main(): Promise<void> {
  // Create AI Project client
  const project = new AIProjectClient(projectEndpoint, new DefaultAzureCredential());
  const openAIClient = await project.getOpenAIClient();

  // Create agent
  console.log("Creating agent...");
  const agent = await project.agents.createVersion(agentName, {
    kind: "prompt",
    model: modelDeploymentName,
    instructions: "You are a helpful assistant that answers general questions",
  });
  console.log(`Agent created (id: ${agent.id}, name: ${agent.name}, version: ${agent.version})`);
}

main().catch(console.error);