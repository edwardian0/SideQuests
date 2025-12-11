#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed May 14 13:00:19 2025

@author: cmc2918
"""

# models/train_normalised.py

# Contains training/validation loops, loss functions, and metrics

import torch
import numpy as np
import matplotlib.pyplot as plt
from sklearn.metrics import r2_score, mean_squared_error
from sklearn.preprocessing import MinMaxScaler
from torch_geometric.loader import DataLoader
from torch.nn import MSELoss
from models.mpnn_model import MPNNModel

def train_model(graphs, batch_size=16, lr=1e-3, epochs=300, hidden_dim=64):
    """
    Function to train the MPNN model with MinMax normalised targets.
    """
    
    all_targets = torch.cat([g.y for g in graphs]).view(-1,1).numpy()
    scaler = MinMaxScaler()
    scaler.fit(all_targets)
    
    # Scale the y-values in place
    for g in graphs:
        g.y = torch.tensor(scaler.transform(g.y.view(-1,1)), dtype=torch.float)
        
    # Auto-detect number of input features from the first graph 

    # By design, each node has the same number of feautres in graph-based
    # learning. GNNs require fixed-size feature vectors per node (and edge) to 
    # ensure tensor consistency during message passing, batching, backprop, etc. 
  
    in_channels = graphs[0].x.size(1); edge_dim = graphs[0].edge_attr.size(1)
    model = MPNNModel(in_channels, edge_dim, hidden_dim)
    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    loss_fn = MSELoss()

    loader = DataLoader(graphs, batch_size=batch_size, shuffle=True)
    
    model.train()
    
    # Training loop
    for epoch in range(epochs):
        total_loss = 0
        for batch in loader:
            optimizer.zero_grad()
            out = model(batch.x, batch.edge_index, batch.edge_attr, batch.batch)
            loss = loss_fn(out.squeeze(), batch.y.view(-1))
            loss.backward()
            optimizer.step()
            total_loss += loss.item()
        
        print(f"Epoch {epoch+1}, Loss: {total_loss:.4f}")

    # After training, plot predictions
    plot_predictions(model, loader, scaler)
    
    return model

def plot_predictions(model, loader, scaler):
    """
    Function to plot predictions vs actual values.
    """
    all_preds, all_targets = [], []
    
    model.eval()
    with torch.no_grad():
        for batch in loader:
            preds = model(batch.x, batch.edge_index, batch.edge_attr, batch.batch)
            all_preds.append(preds.squeeze())
            all_targets.append(batch.y.view(-1))

    # Concatenate all predictions and targets
    all_preds = torch.cat(all_preds).cpu().numpy().reshape(-1,1)
    all_targets = torch.cat(all_targets).cpu().numpy().reshape(-1,1)
    
    # Inverse transform back to original scale
    all_preds_orig = scaler.inverse_transform(all_preds).flatten()
    all_targets_orig = scaler.inverse_transform(all_targets).flatten()

    # Calculate R² and RMSE
    r2 = r2_score(all_targets_orig, all_preds_orig)
    rmse = np.sqrt(mean_squared_error(all_targets_orig, all_preds_orig))

    print(f"R² score: {r2:.3f}")
    print(f"RMSE: {rmse:.3f}")

    # Plot actual vs predicted values
    plt.figure(figsize=(6, 6))
    plt.scatter(all_targets_orig, all_preds_orig, alpha=0.7)
    plt.plot([all_targets_orig.min(), all_targets_orig.max()], 
             [all_targets_orig.min(), all_targets_orig.max()], 'r--')
    plt.xlabel("Actual")
    plt.ylabel("Predicted")
    plt.title("Predicted vs. Actual")
    plt.grid(True)
    plt.tight_layout()
    plt.show()

# models/train.py

# import os
# import numpy as np
# import pandas as pd
# import torch
# import matplotlib.pyplot as plt
# from torch.nn import MSELoss
# from torch_geometric.loader import DataLoader
# from sklearn.metrics import r2_score
# from models.mpnn_architecture import MPNNModel

# def plot_and_save_predictions(preds, targets, smiles, output_path="data/processed/mpnn_predictions.csv", top_n=5):
#     df = pd.DataFrame({
#         'Inhibitor': smiles,
#         'Actual': targets,
#         'Predicted': preds,
#         'Absolute Error': np.abs(targets - preds)
#     })

#     os.makedirs(os.path.dirname(output_path), exist_ok=True)
#     df.to_csv(output_path, index=False)
#     print(f"Saved predictions to {output_path}")

#     # Print worst predictions
#     worst_preds = df.sort_values(by="Absolute Error", ascending=False).head(top_n)
#     print("\nWorst Predictions:\n", worst_preds)

#     # Plot actual vs predicted
#     plt.figure(figsize=(6, 6))
#     plt.scatter(targets, preds, alpha=0.6)
#     plt.plot([targets.min(), targets.max()], [targets.min(), targets.max()], 'r--')
#     plt.xlabel("Actual Inhibition Efficiency")
#     plt.ylabel("Predicted Inhibition Efficiency")
#     plt.title("Actual vs Predicted Inhibition Efficiency")
#     plt.grid(True)
#     plt.tight_layout()
#     plt.show()

# def train_model(graphs, batch_size=16, lr=1e-3, epochs=500, hidden_dim=64):
#     in_channels = graphs[0].x.shape[1]
#     model = MPNNModel(in_channels=in_channels, hidden_dim=hidden_dim)
#     optimizer = torch.optim.Adam(model.parameters(), lr=lr)
#     loss_fn = MSELoss()

#     loader = DataLoader(graphs, batch_size=batch_size, shuffle=True)

#     model.train()
#     for epoch in range(epochs):
#         total_loss = 0
#         for batch in loader:
#             optimizer.zero_grad()
#             out = model(batch.x, batch.edge_index, batch.batch)
#             loss = loss_fn(out.squeeze(), batch.y)
#             loss.backward()
#             optimizer.step()
#             total_loss += loss.item()
#         print(f"Epoch {epoch+1}, Loss: {total_loss:.4f}")

#     # Evaluation on full dataset
#     model.eval()
#     all_preds, all_targets = [], []
#     for batch in loader:
#         pred = model(batch.x, batch.edge_index, batch.batch)
#         all_preds.extend(pred.squeeze().detach().cpu().numpy())
#         all_targets.extend(batch.y.cpu().numpy())

#     all_preds = np.array(all_preds)
#     all_targets = np.array(all_targets)

#     r2 = r2_score(all_targets, all_preds)
#     print(f"\nR² Score on Full Dataset: {r2:.4f}")

#     # Load SMILES for reporting
#     smiles_path = "data/processed/input.csv"
#     if os.path.exists(smiles_path):
#         smiles_list = pd.read_csv(smiles_path)["Inhibitor Name"].tolist()
#         plot_and_save_predictions(all_preds, all_targets, smiles_list[:len(all_preds)])
#     else:
#         print("SMILES file not found. Skipping prediction CSV and plotting.")

#     return model
