#!/usr/bin/env python3
import argparse

from mlx_lm import generate, load


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate text locally with MLX-LM.")
    parser.add_argument(
        "--model",
        default="mlx-community/Qwen2.5-0.5B-Instruct-4bit",
        help="Hugging Face model id or local MLX model path.",
    )
    parser.add_argument("--prompt", default="Explique MLX em uma frase.")
    parser.add_argument("--max-tokens", type=int, default=120)
    args = parser.parse_args()

    model, tokenizer = load(args.model)
    text = generate(
        model,
        tokenizer,
        prompt=args.prompt,
        max_tokens=args.max_tokens,
        verbose=True,
    )
    print(text)


if __name__ == "__main__":
    main()
