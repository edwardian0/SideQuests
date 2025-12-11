#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri May 16 16:19:15 2025

@author: cmc2918
"""

# models/train.py

import torch
import numpy as np
import matplotlib.pyplot as plt
from sklearn.metrics import r2_score, mean_squared_error
from torch_geometric.loader import DataLoader
from torch.nn import MSELoss
from models.mpnn_model import MPNNModel

def train_model(graphs, batch_size=16, lr=1e-3, epochs=300, hidden_dim=64):
    """
    Function to train the MPNN model without normalizing targets.
    """
    in_channels = graphs[0].x.size(1)
    edge_dim = graphs[0].edge_attr.size(1)
    model = MPNNModel(in_channels, edge_dim, hidden_dim)
    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    loss_fn = MSELoss()

    loader = DataLoader(graphs, batch_size=batch_size, shuffle=True)
    model.train()

    for epoch in range(epochs):
        total_loss = 0
        for batch in loader:
            optimizer.zero_grad()
            out = model(batch.x, batch.edge_index, batch.edge_attr, batch.batch)
            loss = loss_fn(out.squeeze(), batch.y.squeeze())
            loss.backward()
            optimizer.step()
            total_loss += loss.item()

        print(f"Epoch {epoch+1}, Loss: {total_loss:.4f}")

    plot_predictions(model, loader)
    return model

def plot_predictions(model, loader):
    """
    Function to plot predictions vs actual values without scaling.
    """
    all_preds, all_targets = [], []

    model.eval()
    with torch.no_grad():
        for batch in loader:
            preds = model(batch.x, batch.edge_index, batch.edge_attr, batch.batch)
            all_preds.append(preds.squeeze())
            all_targets.append(batch.y.squeeze())

    all_preds = torch.cat(all_preds).cpu().numpy()
    all_targets = torch.cat(all_targets).cpu().numpy()

    r2 = r2_score(all_targets, all_preds)
    rmse = np.sqrt(mean_squared_error(all_targets, all_preds))

    print(f"R² score: {r2:.3f}")
    print(f"RMSE: {rmse:.3f}")

    plt.figure(figsize=(6, 6))
    plt.scatter(all_targets, all_preds, alpha=0.7)
    plt.plot([all_targets.min(), all_targets.max()], 
             [all_targets.min(), all_targets.max()], 'r--')
    plt.xlabel("Actual")
    plt.ylabel("Predicted")
    plt.title("Predicted vs. Actual")
    plt.grid(True)
    plt.tight_layout()
    plt.show()
    