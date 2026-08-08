"""Kronos 快速验证脚本：加载本地模型 + 跑一次预测"""
import sys, time
import numpy as np
import pandas as pd
import torch

from model import Kronos, KronosTokenizer, KronosPredictor

def main():
    t0 = time.time()
    print(f"torch {torch.__version__}, mps={torch.backends.mps.is_available()}")

    # 本地模型路径（已从 hf-mirror 下载）
    tok_path = "models/NeoQuasar/Kronos-Tokenizer-base"
    model_path = "models/NeoQuasar/Kronos-small"

    print("加载 tokenizer ...")
    tokenizer = KronosTokenizer.from_pretrained(tok_path)
    print(f"  tokenizer 加载完成 {time.time()-t0:.1f}s")

    print("加载模型 ...")
    model = Kronos.from_pretrained(model_path)
    n_params = sum(p.numel() for p in model.parameters())
    print(f"  model 加载完成 {time.time()-t0:.1f}s, params={n_params/1e6:.1f}M")

    device = "mps" if torch.backends.mps.is_available() else "cpu"
    # MPS 的 scaled_dot_product_attention 不支持 dropout，推理必须 eval 模式
    tokenizer.eval()
    model.eval()
    predictor = KronosPredictor(model, tokenizer, max_context=512, device=device)
    print(f"predictor 就绪 (device={device})")

    # 用测试数据跑预测
    df = pd.read_csv("tests/data/regression_input.csv")
    df["timestamps"] = pd.to_datetime(df["timestamps"])
    print(f"数据: {df.shape[0]} 行, {df.columns.tolist()}")

    lookback, pred_len = 400, 30
    x_df = df.loc[:lookback-1, ["open", "high", "low", "close", "volume", "amount"]]
    x_ts = df.loc[:lookback-1, "timestamps"]
    y_ts = df.loc[lookback:lookback+pred_len-1, "timestamps"]

    t1 = time.time()
    pred_df = predictor.predict(
        df=x_df, x_timestamp=x_ts, y_timestamp=y_ts,
        pred_len=pred_len, T=1.0, top_p=0.9, sample_count=1,
    )
    print(f"预测完成 {time.time()-t1:.1f}s")
    print("\n预测结果 head:")
    print(pred_df.head(5).round(4))
    print("\n预测结果 tail:")
    print(pred_df.tail(3).round(4))

    # 与实际值对比（用 .values 避免索引对齐问题）
    actual = df.loc[lookback:lookback+pred_len-1, ["open", "high", "low", "close"]].reset_index(drop=True).values
    mae_all = np.abs(pred_df[["open", "high", "low", "close"]].values - actual).mean()
    mae_close = np.abs(pred_df["close"].values - actual[:, 3]).mean()
    print(f"\n预测 vs 实际 close MAE: {mae_close:.4f}")
    print(f"全部列 (OHLC) MAE: {mae_all:.4f}")
    print(f"\n✅ 总耗时 {time.time()-t0:.1f}s — 跑通!")

if __name__ == "__main__":
    main()
