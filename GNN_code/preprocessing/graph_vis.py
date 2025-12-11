#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed May 14 11:22:38 2025

@author: cmc2918
"""

import pandas as pd
from rdkit import Chem
# from rdkit.Chem import Draw
from rdkit.Chem.Draw import rdMolDraw2D

# Load the CSV
df = pd.read_csv("../data/processed/input.csv")  # Adjust path as needed

# Select the first SMILES string (or any index from the original spreadsheet)
smiles = df.loc[0, "SMILES"]
mol = Chem.MolFromSmiles(smiles)

def draw_mol_with_indices(mol):
    mol = Chem.Mol(mol)  # deep copy
    drawer = rdMolDraw2D.MolDraw2DCairo(400, 300)
    drawer.drawOptions().addAtomIndices = True
    drawer.drawOptions().addBondIndices = True
    rdMolDraw2D.PrepareAndDrawMolecule(drawer, mol)
    drawer.FinishDrawing()
    return drawer.GetDrawingText()

# Save the image with indices
with open("molecule_0_with_indices.png", "wb") as f:
    f.write(draw_mol_with_indices(mol))

# Basic image
# img = Draw.MolToImage(mol, size=(400, 300))
# img.show()

####   --------------------------------------------------------------- ####

from preprocessing.smiles_to_graph import batch_from_csv
graphs = batch_from_csv("../data/processed/input.csv")

from torch_geometric.utils import to_networkx
import matplotlib.pyplot as plt
import networkx as nx

def visualize_molecular_graph(data, idx=None):
    """Visualize one PyG Data object as a molecular graph."""
    G = to_networkx(data, to_undirected=True)
    pos = nx.spring_layout(G, seed=42)
    nx.draw(G, pos, with_labels=True, node_color='skyblue', edge_color='gray', node_size=500, font_size=10)
    if idx is not None:
        plt.title(f"Molecule #{idx}")
    plt.show()

# Example: visualize first 5 molecules
for idx, data in enumerate(graphs[:5]):
    visualize_molecular_graph(data, idx)
