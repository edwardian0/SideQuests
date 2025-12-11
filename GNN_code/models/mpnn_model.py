#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed May 14 15:01:45 2025

@author: cmc2918
"""

# models/mpnn_model.py

# This script takes the MPNN framework defined in Gilmer et al., 2017, stack it 
# with a non-linear activation function and include a readout to be fed 
# into a final MLP regression layer (wrt inhibition efficiency).

import torch
from torch.nn import Linear, ReLU, Dropout, Sequential
from torch_geometric.nn import NNConv, global_mean_pool

class MPNNModel(torch.nn.Module):
    def __init__(self, in_channels, edge_dim, hidden_dim, out_dim=1, dropout_rate=0.2):
        super().__init__()
        
        # Edge network for the first layer
        # Maps edge features to a weight matrix for message passing
        self.edge_nn1 = Sequential(
            Linear(edge_dim, hidden_dim * in_channels),
            ReLU(),
            Linear(hidden_dim * in_channels, hidden_dim * in_channels)
        )

        # GNN Encoder for the first layer
        self.conv1 = NNConv(in_channels, hidden_dim, nn=self.edge_nn1, aggr='add')
        
        # Second edge network (can share or reuse logic, but typically kept separate)
       #  self.edge_nn2 = Sequential(
       #      Linear(edge_dim, hidden_dim * hidden_dim), 
       #      ReLU(), 
       #      Linear(hidden_dim * hidden_dim, hidden_dim * hidden_dim)
       # )
        
       # GNN Encoder for the second layer
        # self.conv2 = NNConv(hidden_dim, hidden_dim, nn=self.edge_nn2, aggr='add')

        # Feedforward MLP for regression
        self.ffnn = Sequential(
            Linear(hidden_dim, hidden_dim), # size of hidden layers (e.g. 64,128)
            ReLU(), # activation function
            Dropout(dropout_rate), # regularisation (e.g. 0.2, 0.5)
            Linear(hidden_dim, out_dim) # output layer (default: scalar)
        )

    def forward(self, x, edge_index, edge_attr, batch):
        # First message passing layer
        x = self.conv1(x, edge_index, edge_attr) # Message logic within PyG source code for NNConv
        x = torch.relu(x) # Non-linear update function
        
        # Second message passing layer
        # x = self.conv2(x, edge_index, edge_attr)
        # x = torch.relu(x) 

        # Graph readout (pooling)
        x = global_mean_pool(x, batch)

        # Feedforward regression head
        out = self.ffnn(x)
        return out
