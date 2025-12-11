#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue May 13 17:21:41 2025

@author: cmc2918
"""

# preprocessing/fetch_smiles.py

import pandas as pd
import pubchempy as pcp
from rdkit import Chem
from tqdm import tqdm
import os

def is_valid_smiles(smiles: str) -> bool: 
    """Returns True if RDKit can parse the SMILES string."""
    try:
        return Chem.MolFromSmiles(smiles) is not None
    except:
        return False

def resolve_smiles_by_cas_interactive(input_path: str, output_path: str, log_path: str = "data/logs/manual_smiles_log.csv") -> pd.DataFrame:
    """
    Resolves SMILES from CAS numbers using PubChem API.
    If not found, prompts for manual input with validation and logs it.
    """
    df = pd.read_excel(input_path)
    df.columns = df.columns.str.strip()
    cas_col = 'CAS Number'
    name_col = 'Inhibitor Name' if 'Inhibitor Name' in df.columns else None

    smiles_list = []
    manual_entries = []

    tqdm.pandas(desc="Resolving SMILES")

    for _, row in tqdm(df.iterrows(), total=len(df), desc="Processing compounds"):
        cas = row[cas_col]
        name = row[name_col] if name_col else None

        # Try PubChem first
        try:
            compounds = pcp.get_compounds(str(cas), 'name')
            if compounds and compounds[0].isomeric_smiles:
                smiles_list.append(compounds[0].isomeric_smiles)
                continue
        except Exception as e:
            print(f"PubChem error for CAS {cas}: {e}")

        # Manual fallback
        display_name = f"{name} (CAS:{cas})" if name else f"CAS: {cas}"
        while True:
            manual = input(f" No SMILES found for {display_name}. Enter SMILES manually (or press Enter to skip): ")
            if not manual.strip():
                smiles_list.append(None)
                break
            elif is_valid_smiles(manual):
                smiles_list.append(manual.strip())
                manual_entries.append({
                    'Inhibitor Name': name,
                    'CAS Number': cas,
                    'SMILES': manual.strip()
                })
                break
            else:
                print("Invalid SMILES. Please try again.")

    df['SMILES'] = smiles_list

    # Save results
    df.to_csv(output_path, index=False)
    print(f" Full dataset with SMILES saved to: {output_path}")

    if manual_entries:
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        pd.DataFrame(manual_entries).to_csv(log_path, index=False)
        print(f" Manual entries logged in: {log_path}")

    return df
