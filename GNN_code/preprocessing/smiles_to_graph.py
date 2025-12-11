#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed May 14 10:16:57 2025

@author: cmc2918
"""
# preprocessing/smiles_to_graph.py

import pandas as pd
import numpy as np
import torch
from torch_geometric.data import Data
from rdkit import Chem
from rdkit.Chem.rdmolops import GetAdjacencyMatrix
from .featurisation import get_atom_features, get_bond_features

def molecule_to_graph(smiles: str, label=None) -> Data:
    """Convert a single SMILES to a PyTorch Geometric graph."""
    mol = Chem.MolFromSmiles(smiles)
    if mol is None:
        raise ValueError(f"Invalid SMILES string: {smiles}")
    
    # Efficient atom feature tensor construction
    atom_features = np.array([get_atom_features(atom) for atom in mol.GetAtoms()], dtype=np.float32)
    x = torch.tensor(atom_features)

    # Adjacency and edges
    adj = GetAdjacencyMatrix(mol)
    rows, cols = np.nonzero(adj)
    edge_index = np.array([rows,cols], dtype=np.int64) 
    edge_index = torch.tensor(edge_index) # edge_index refers to connectivity

    # Edge features
    edge_attr_list = []
    for i, j in zip(rows, cols):
        bond = mol.GetBondBetweenAtoms(int(i), int(j))
        edge_attr_list.append(get_bond_features(bond))
    edge_attr_array = np.array(edge_attr_list, dtype=np.float32)
    edge_attr = torch.tensor(edge_attr_array) # edge_attr refer to bond characterisation 

    y_tensor = torch.tensor([label], dtype=torch.float) if label is not None else None

    return Data(x=x, edge_index=edge_index, edge_attr=edge_attr, y=y_tensor)

def batch_from_csv(csv_path: str, smiles_col="SMILES", label_col="Inh Power") -> list:
    """Convert a CSV with SMILES (and optional labels) into a list of Data graphs."""
    df = pd.read_csv(csv_path)
    data_list = []
    for _, row in df.iterrows():
        smiles = row[smiles_col]
        label = row[label_col] if label_col else None
        try:
            graph = molecule_to_graph(smiles, label)
            data_list.append(graph)
        except Exception as e:
            print(f"Skipping molecule: {smiles} due to error: {e}")
    return data_list
