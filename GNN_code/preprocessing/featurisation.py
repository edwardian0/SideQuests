#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Wed May 14 09:06:19 2025

@author: cmc2918
"""

# preprocessing/featurisation.py

import numpy as np
from rdkit import Chem

# Define an auxiliary function which transforms a value x into a one-hot encoding based on a list of permitted values for x:
def one_hot_encoding(x, permitted_list):
    if x not in permitted_list:
        x = permitted_list[-1]
    return [int(x == s) for s in permitted_list]

# Define a function that maps an RDKit atom object to a suitable atom feature vector.
def get_atom_features(atom, use_chirality=True, hydrogens_implicit=True):
    """
    Takes an RDKit atom object as input and returns a numpy vector of 
    atom (nodes in molecular graph) features as output. 
    """
    permitted_atoms = [
        'C', 'N', 'O', 'S', 'F', 'Si', 'P', 'Cl', 'Br', 'Mg', 'Na', 'Ca', 'Fe',
        'As', 'Al', 'I', 'B', 'V', 'K', 'Tl', 'Yb', 'Sb', 'Sn', 'Ag', 'Pd', 'Co',
        'Se', 'Ti', 'Zn', 'Li', 'Ge', 'Cu', 'Au', 'Ni', 'Cd', 'In', 'Mn', 'Zr',
        'Cr', 'Pt', 'Hg', 'Pb', 'Unknown'
    ]
    if hydrogens_implicit == False:
        permitted_atoms = ['H'] + permitted_atoms

    atom_type = one_hot_encoding(str(atom.GetSymbol()), permitted_atoms) 
    degree = atom.GetDegree() # Degree of an atom is the number of directly-bonded neighbours
    degree_enc = one_hot_encoding(min(degree, 4) if degree <= 4 else "MoreThanFour", [0, 1, 2, 3, 4, "MoreThanFour"])
    charge = atom.GetFormalCharge() # Formal charge
    charge_enc = one_hot_encoding(charge if abs(charge) <= 3 else "Extreme", [-3, -2, -1, 0, 1, 2, 3, "Extreme"])
    hybrid = one_hot_encoding(str(atom.GetHybridization()), ["S", "SP", "SP2",
                                              "SP3", "SP3D", "SP3D2", "OTHER"]) #Hybridisation type
    ring = [int(atom.IsInRing())] # Whether the atom is in a ring
    aromatic = [int(atom.GetIsAromatic())] # Whether the atom is in an aromatic ring

    pt = Chem.GetPeriodicTable() 
    mass = [(atom.GetMass() - 10.812) / 116.092] # Scaled atomic mass
    vdw = [(pt.GetRvdw(atom.GetAtomicNum()) - 1.5) / 0.6] # Scaled VdW radius
    covalent = [(pt.GetRcovalent(atom.GetAtomicNum()) - 0.64) / 0.76] # Scaled covalent radius

    node_features = atom_type + degree_enc + charge_enc + hybrid + ring + aromatic + mass + vdw + covalent

    if use_chirality:
        node_features += one_hot_encoding(str(atom.GetChiralTag()), ["CHI_UNSPECIFIED", 
        "CHI_TETRAHEDRAL_CW", "CHI_TETRAHEDRAL_CCW", "CHI_OTHER"])

    if hydrogens_implicit:
        n_h = atom.GetTotalNumHs()
        node_features += one_hot_encoding(min(n_h, 4) if n_h <= 4 else "MoreThanFour", [0, 1, 2, 3, 4, "MoreThanFour"])

    return np.array(node_features)

def get_bond_features(bond, use_stereochemistry=True):
    """
    Takes an RDKit atom object as input and returns a numpy vector of 
    bond (edges in molecular graph) features as output. 
    """
    permitted_bond_types = [Chem.rdchem.BondType.SINGLE, Chem.rdchem.BondType.DOUBLE,
                            Chem.rdchem.BondType.TRIPLE, Chem.rdchem.BondType.AROMATIC]
    bond_type = one_hot_encoding(bond.GetBondType(), permitted_bond_types)
    conjugated = [int(bond.GetIsConjugated())]
    in_ring = [int(bond.IsInRing())]

    edge_features = bond_type + conjugated + in_ring

    if use_stereochemistry:
        stereo = one_hot_encoding(str(bond.GetStereo()), ["STEREOZ", "STEREOE", "STEREOANY", "STEREONONE"])
        edge_features += stereo

    return np.array(edge_features)

