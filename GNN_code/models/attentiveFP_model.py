import torch
from torch.nn import Linear, ReLU, Dropout, Sequential
from torch_geometric.nn import AttentiveFP
import torch
from torch_geometric.loader import DataLoader
import numpy as np
import matplotlib.pyplot as plt
from sklearn.metrics import r2_score, root_mean_squared_error

class AttentiveFPModel(torch.nn.Module):
    def __init__(self, node_dim, edge_dim, hidden_dim, out_dim, num_layers=1, timesteps=2, dropout_rate=0.2):
        super().__init__()

        self.attentivefp = AttentiveFP(
            in_channels=node_dim,
            hidden_channels=hidden_dim,
            out_channels=hidden_dim,  # should match Linear input
            edge_dim=edge_dim,
            num_layers=num_layers,
            num_timesteps=timesteps,
            dropout=dropout_rate
        )

        self.ffnn = Sequential(
            Linear(hidden_dim, hidden_dim),
            ReLU(),
            Dropout(dropout_rate),
            Linear(hidden_dim, out_dim)
        )

    def forward(self, data):
        x = self.attentivefp(data.x, data.edge_index, data.edge_attr, data.batch)
        return self.ffnn(x)



def train_attFP_model(model, loader, lr=1e-3, epochs=300):
    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    loss_fn = torch.nn.MSELoss()

    model.train()
    for epoch in range(epochs):
        total_loss = 0
        for batch in loader:
            optimizer.zero_grad()
            out = model(batch).squeeze()
            target = batch.y.squeeze()

            # Shape fix
            if out.dim() == 0:
                out = out.unsqueeze(0)
            if target.dim() == 0:
                target = target.unsqueeze(0)

            assert out.shape == target.shape, f"{out.shape=} vs {target.shape=}"

            loss = loss_fn(out, target)
            loss.backward()
            optimizer.step()
            total_loss += loss.item()

        print(f"Epoch {epoch + 1}: Loss = {total_loss:.4f}")
    return model


def plot_predictions_attFP(model, loader):

    model.eval()
    preds, targets = [], []

    with torch.no_grad():
        for batch in loader:
            out = model(batch).squeeze()
            y = batch.y.squeeze()
            preds.append(out.cpu())
            targets.append(y.cpu())

    preds = torch.cat(preds).numpy()
    targets = torch.cat(targets).numpy()

    print(f"R²: {r2_score(targets, preds):.3f}")
    print(f"RMSE: {root_mean_squared_error(targets, preds):.3f}")

    plt.figure(figsize=(6, 6))
    plt.scatter(targets, preds, alpha=0.6)
    plt.plot([targets.min(), targets.max()], [targets.min(), targets.max()], 'r--')
    plt.xlabel("Actual")
    plt.ylabel("Predicted")
    plt.title("Predictions vs Actual - AttentiveFP (Batched)")
    plt.grid(True)
    plt.tight_layout()
    plt.show()
