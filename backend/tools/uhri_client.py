"""UHRI (Universal Human Rights Index) API client.

Fetches human rights recommendations from the UN OHCHR database.
Data source: https://uhri.ohchr.org/en/our-data-api
"""

import httpx

from src.app.core.config import get_settings


class UHRIClient:
    """Client for fetching data from the UN Human Rights Index."""

    # Full dataset export URL
    EXPORT_URL = "https://dataex.ohchr.org/uhri/export-results/export-full-en.json"

    def __init__(self, timeout: float = 120.0) -> None:
        """Initialize the UHRI client.

        Args:
            timeout: HTTP request timeout in seconds (default 120s for large downloads)
        """
        self.timeout = timeout
        self._settings = get_settings()

    async def fetch_full_dataset(self) -> list[dict]:
        """Fetch the complete UHRI dataset.

        Returns:
            List of recommendation records from UHRI.

        Raises:
            httpx.HTTPError: If the request fails.
        """
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.get(self.EXPORT_URL)
            response.raise_for_status()
            return response.json()

    async def fetch_sample_data(self, limit: int = 100) -> list[dict]:
        """Fetch a sample of UHRI data for testing.

        This fetches the full dataset but returns only the first N records.
        Use for development/testing to avoid processing the entire dataset.

        Args:
            limit: Maximum number of records to return.

        Returns:
            List of recommendation records (limited).
        """
        data = await self.fetch_full_dataset()
        return data[:limit]


# Sample data for offline development/testing
SAMPLE_UHRI_DATA = [
    {
        "id": "1",
        "country": "Kenya",
        "mechanism": "UPR",
        "cycle": "3rd Cycle",
        "year": "2020",
        "recommending_state": "Germany",
        "recommendation": "Ratify the Optional Protocol to the Convention against Torture and establish a national preventive mechanism.",
        "theme": "Torture and ill-treatment",
        "status": "Noted",
    },
    {
        "id": "2",
        "country": "Kenya",
        "mechanism": "CERD",
        "cycle": "Committee on the Elimination of Racial Discrimination",
        "year": "2017",
        "recommending_state": None,
        "recommendation": "The Committee recommends that the State party adopt comprehensive anti-discrimination legislation that includes a definition of racial discrimination.",
        "theme": "Racial discrimination",
        "status": "Pending",
    },
    {
        "id": "3",
        "country": "Brazil",
        "mechanism": "UPR",
        "cycle": "3rd Cycle",
        "year": "2022",
        "recommending_state": "Norway",
        "recommendation": "Strengthen measures to protect human rights defenders, journalists and environmental activists from threats and attacks.",
        "theme": "Human rights defenders",
        "status": "Accepted",
    },
    {
        "id": "4",
        "country": "India",
        "mechanism": "CCPR",
        "cycle": "Human Rights Committee",
        "year": "2023",
        "recommending_state": None,
        "recommendation": "The State party should ensure that all allegations of extrajudicial killings are promptly, thoroughly and independently investigated.",
        "theme": "Right to life",
        "status": "Pending",
    },
    {
        "id": "5",
        "country": "United States",
        "mechanism": "CAT",
        "cycle": "Committee against Torture",
        "year": "2022",
        "recommending_state": None,
        "recommendation": "The State party should take effective measures to prevent and combat racial profiling by law enforcement officials.",
        "theme": "Law enforcement",
        "status": "Pending",
    },
    {
        "id": "6",
        "country": "China",
        "mechanism": "UPR",
        "cycle": "4th Cycle",
        "year": "2024",
        "recommending_state": "United Kingdom",
        "recommendation": "Allow unfettered access to Xinjiang for independent investigators, including the Office of the High Commissioner for Human Rights.",
        "theme": "Minorities",
        "status": "Noted",
    },
    {
        "id": "7",
        "country": "Syria",
        "mechanism": "HRC",
        "cycle": "Human Rights Council",
        "year": "2023",
        "recommending_state": None,
        "recommendation": "Immediately cease all attacks on civilian infrastructure, including hospitals and schools, and ensure accountability for violations of international humanitarian law.",
        "theme": "Armed conflict",
        "status": "Pending",
    },
    {
        "id": "8",
        "country": "South Africa",
        "mechanism": "CEDAW",
        "cycle": "Committee on the Elimination of Discrimination against Women",
        "year": "2021",
        "recommending_state": None,
        "recommendation": "Adopt a comprehensive strategy to combat gender-based violence, including femicide, with adequate funding and monitoring mechanisms.",
        "theme": "Gender-based violence",
        "status": "Pending",
    },
    {
        "id": "9",
        "country": "Mexico",
        "mechanism": "CED",
        "cycle": "Committee on Enforced Disappearances",
        "year": "2022",
        "recommending_state": None,
        "recommendation": "Urgently address the crisis of enforced disappearances by strengthening search mechanisms and ensuring effective investigation of all cases.",
        "theme": "Enforced disappearances",
        "status": "Pending",
    },
    {
        "id": "10",
        "country": "Russia",
        "mechanism": "UPR",
        "cycle": "4th Cycle",
        "year": "2023",
        "recommending_state": "France",
        "recommendation": "Release all persons detained for exercising their rights to freedom of expression, peaceful assembly and association.",
        "theme": "Freedom of expression",
        "status": "Noted",
    },
]
