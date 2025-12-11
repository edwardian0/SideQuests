import requests
from bs4 import BeautifulSoup

def render_grid_from_doc(url: str):
    # Fetch the published Google Doc HTML
    response = requests.get(url)
    response.raise_for_status()
    soup = BeautifulSoup(response.text, "html.parser")

    # Extract rows of the table
    rows = soup.find_all("tr")

    coordinates = []  # store tuples (x, y, char)

    for row in rows[1:]:  # skip header row
        cols = row.find_all("td")
        if len(cols) != 3:
            continue
        x = int(cols[0].get_text(strip=True))
        char = cols[1].get_text(strip=True)
        y = int(cols[2].get_text(strip=True))
        coordinates.append((x, y, char))

    if not coordinates:
        print("No coordinates found.")
        return

    # Find grid size
    max_x = max(x for x, _, _ in coordinates)
    max_y = max(y for _, y, _ in coordinates)

    # Initialize grid with spaces
    grid = [[" " for _ in range(max_x + 1)] for _ in range(max_y + 1)]

    # Place characters
    for x, y, char in coordinates:
        grid[y][x] = char

    # Print the grid
    for row in grid:
        print("".join(row))

url = "https://docs.google.com/document/d/e/2PACX-1vRPzbNQcx5UriHSbZ-9vmsTow_R6RRe7eyAU60xIF9Dlz-vaHiHNO2TKgDi7jy4ZpTpNqM7EvEcfr_p/pub"
render_grid_from_doc(url)