# MiMir AI

## The problem MimirAI solves
With rise of GenAI now, creators, artists lack the economic and business model, don't get compensated for their work since AI just scrape the content online, which may infringe copyright law. Moreover, content creators' work can be misused, result in fake datas. The solution for both trustless AI inference and the data marketplace that compensates creators fairly is needed.

Mirmir AI is a decentralized AI oracle and private data and model market that compensates for creators:

## Features:

- Creators can monetize the AI model or their dataset without revealing the data and also set licensing and IP terms via Story Protocol
- The AI inference is trustless using Lit Actions, which executes LLM query in TEEs, so the AI inference is done without revealing the data
- Creators and community can verify the data via the AI Oracle.

## How it works:

- Creators can register their dataset via Story Protocol
- User creates an LLM query
- The LLM query is done inside Lit Actions. Users don't see the input data.
- Lit Actions return results back to the user, The query and result is verifable, but the input data remains private.

## Challenges I ran into
- Integrating Lit Protocol and also build a custom AI Oracle in Story Protocol testnet
- Need to get familiar with Lit Actions and Integrating Story Protocol contracts