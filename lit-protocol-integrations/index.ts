import { LitNodeClient } from "@lit-protocol/lit-node-client";
import { LitNetwork, LIT_RPC } from "@lit-protocol/constants";
import { ethers, BigNumber } from "ethers";
import {
    RPC_URL,
    ORACLE_ADDRESS,
    ORACLE_ABI
} from "./constants";
import {
    createSiweMessageWithRecaps,
    generateAuthSig,
    LitAbility,
    LitActionResource,
    LitPKPResource,
  } from "@lit-protocol/auth-helpers";
import * as fs from "fs";
// import { litActionCode } from "./litAction";

import dotenv from "dotenv";
dotenv.config();

async function processPromptAddedEvent(
    event: ethers.Event & {
      args: {
        promptId: BigNumber;
        promptCallbackId: BigNumber;
        sender: string;
      };
    },
    messagesRoles: any,
    litNodeClient: LitNodeClient,
    sessionSigs: any
  ): Promise<void> {
    console.log("New PromptAdded event detected!");
    console.log(`Prompt ID: ${event.args.promptId.toString()}`);
    console.log(`Prompt Callback ID: ${event.args.promptCallbackId.toString()}`);
    console.log(`Sender: ${event.args.sender}`);
    console.log(`Block number: ${event.blockNumber}`);
  
    try {
      console.log("Executing Lit Action...");
      const result = await litNodeClient.executeJs({
        sessionSigs,
        code: fs.readFileSync("litAction.ts", "utf8"),
        jsParams: {
          messagesRoles: messagesRoles,
          promptId: event.args.promptId,
          promptCallbackId: event.args.promptCallbackId,
        },
      });
      console.log("Lit Action executed successfully. Result:", result);
  
      if (result.response) {
        console.log("Lit Action response:");
        console.log(JSON.stringify(result.response, null, 2));
      }
    } catch (error) {
      console.error("Error during Lit Action execution:", error);
    }
}

async function startEventListener(
    contract: ethers.Contract,
    provider: ethers.providers.Provider,
    litNodeClient: LitNodeClient,
    sessionSigs: any
  ): Promise<void> {
    console.log("Starting event listener...");
    const latestBlock = await provider.getBlockNumber();
    console.log(`Current block number: ${latestBlock}`);
  
    contract.on(
      "PromptAdded",
      async (
        promptId: BigNumber,
        promptCallbackId: BigNumber,
        sender: string,
        event: ethers.Event
      ) => {
        if (event.blockNumber > latestBlock) {
          try {
            console.log("Attempting to get messages...");
            const messagesRoles = await contract.getMessagesAndRoles(
              promptId,
              promptCallbackId
            );
            console.log("Messages retrieved successfully:", messagesRoles);
            await processPromptAddedEvent(
              event as ethers.Event & {
                args: {
                  promptId: BigNumber;
                  promptCallbackId: BigNumber;
                  sender: string;
                };
              },
              messagesRoles,
              litNodeClient,
              sessionSigs
            );
          } catch (error) {
            console.error("Error processing PromptAdded event:", error);
          }
        } else {
          console.log(`Skipping old event from block ${event.blockNumber}`);
        }
      }
    );
  
    console.log(
      "Event listener is now active and waiting for new PromptAdded events..."
    );
}

async function main() {
    console.log("Starting the process...");

    const mnemonic = process.env.WALLET_MNEMONIC;
    if (!mnemonic) {
        throw new Error("WALLET_MNEMONIC is not set in the .env file");
    }

    console.log("Creating wallet from mnemonic...");
    const wallet = ethers.Wallet.fromMnemonic(mnemonic);

    const storyRpcProvider = new ethers.providers.JsonRpcProvider(RPC_URL);
    const ethersSigner = wallet.connect(storyRpcProvider);
    console.log("Wallet created successfully. Address:", ethersSigner.address);

    const contract = new ethers.Contract(
        ORACLE_ADDRESS,
        ORACLE_ABI,
        storyRpcProvider
    );

    console.log("Initializing LitNodeClient...");
    const litNodeClient = new LitNodeClient({
        litNetwork: LitNetwork.DatilDev,
        debug: false
    });

    try {
        console.log("Connecting to LitNodeClient...");
        await litNodeClient.connect();
        console.log("✅ Connected to Lit network successfully.");

        console.log("🔄 Getting Session Signatures...");
        const sessionSigs = await litNodeClient.getSessionSigs({
          chain: "ethereum",
          expiration: new Date(Date.now() + 1000 * 60 * 60 * 24).toISOString(), // 24 hours
          resourceAbilityRequests: [
            {
              resource: new LitActionResource("*"),
              ability: LitAbility.LitActionExecution,
            },
          ],
          authNeededCallback: async ({
            resourceAbilityRequests,
            expiration,
            uri,
          }) => {
            console.log("Generating auth signature...");
            const toSign = await createSiweMessageWithRecaps({
              uri: uri!,
              expiration: expiration!,
              resources: resourceAbilityRequests!,
              walletAddress: ethersSigner.address,
              nonce: await litNodeClient.getLatestBlockhash(),
              litNodeClient,
            });
    
            return await generateAuthSig({
              signer: ethersSigner,
              toSign,
            });
          },
        });
        console.log("✅ Got Session Signatures");

        await startEventListener(
            contract,
            storyRpcProvider,
            litNodeClient,
            sessionSigs
        );


    } catch (error) {
        console.error("An error occurred during the setup process:", error);
    }

}

main().catch((error) => {
    console.log("Error occured:", error);
})