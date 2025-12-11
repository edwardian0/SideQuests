from preprocessing.fetch_smiles import resolve_smiles_by_cas_interactive
import pubchempy as pcp
import pandas as pd
from rdkit import Chem
from tqdm import tqdm
import os

 # Example to check if RDKit is working
def is_valid_smiles(smiles: str) -> bool:
    """Returns True if RDKit can parse the SMILES string."""
    try:
        return Chem.MolFromSmiles(smiles) is not None
    except:
        return False
    
cas_number = '64-17-5'  # Example: ethanol

# Use PubChem to get the compound
compounds = pcp.get_compounds(cas_number, 'name')

# Check if found
if compounds:
    compound = compounds[0]
    smiles = compound.canonical_smiles
    print("SMILES:", smiles)

    # Optional: create RDKit molecule
    mol = Chem.MolFromSmiles(smiles)
    print("RDKit Mol:", mol)
else:
    print("Compound not found.")
