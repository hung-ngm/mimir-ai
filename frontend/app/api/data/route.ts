import { NextResponse } from 'next/server';
import * as fs from 'fs';
import * as path from 'path';
import { parse } from 'csv-parse/sync';
import dotenv from 'dotenv';
dotenv.config();

const apiKey = process.env.TOGETHER_API_KEY || "";

export async function POST(request: Request) {
    // Read the CSV file
    const csvFilePath = path.resolve(process.cwd(), 'app/data/ArianaGrande.csv');
    const fileContent = fs.readFileSync(csvFilePath, { encoding: 'utf-8' });

    // Parse the CSV content synchronously
    const records = JSON.stringify(parse(fileContent, {
        columns: true,          // Use first line as headers
        skip_empty_lines: true, // Skip empty lines
    }));

    // Get the user's query from the request body
    const { query } = await request.json();

    const messages = [
        {
            "role": "system",
            "content": "You are analyzing song lyrics dataset. The data is " + records,
        },
        {
            "role": "user",
            "content": query,
        },
    ];

    const payloadInf = {
        "model": "meta-llama/Llama-3.2-11B-Vision-Instruct-Turbo",
        "messages": messages,
    };

    const responseInf = await fetch(
        "https://api.together.xyz/v1/chat/completions",
        {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${apiKey}`,
            },
            method: "POST",
            body: JSON.stringify(payloadInf),
        }
    );
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const resultInf: any = await responseInf.json();
    const answer = resultInf.choices[0].message.content;

    return NextResponse.json({ answer });
}

