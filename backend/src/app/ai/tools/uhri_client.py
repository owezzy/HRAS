"""UHRI (Universal Human Rights Index) API client.

Fetches human rights recommendations from the UN OHCHR database.
Data source: https://uhri.ohchr.org/en/our-data-api
"""

import html
import re

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
            Records in the flat shape the document loader reads (see normalize_export_record).

        Raises:
            httpx.HTTPError: If the request fails.
        """
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.get(self.EXPORT_URL)
            response.raise_for_status()
            return [normalize_export_record(record) for record in response.json()]

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


def _clean(value: object) -> str:
    """Strip the "- " prefix the export puts on enumerated values such as "- CCPR"."""
    return str(value or "").strip().removeprefix("- ").strip()


def _plain_text(html_text: object) -> str:
    """The export's Text field is HTML; keep only the readable text for embedding."""
    without_tags = re.sub(r"<[^>]+>", " ", str(html_text or ""))
    return re.sub(r"\s+", " ", html.unescape(without_tags)).strip()


def _join(values: list | None) -> str:
    return "; ".join(cleaned for cleaned in (_clean(v) for v in values or []) if cleaned)


def normalize_export_record(record: dict) -> dict:
    """Map a record from the UHRI full JSON export to the flat shape the document loader reads.

    The export uses lists for countries, themes and UPR fields, and prefixes enumerated values
    with "- ". Records about several countries keep every name, joined with "; ".
    """
    return {
        "id": record["AnnotationId"],
        "country": _join(record.get("Countries")) or "Unknown",
        "mechanism": _clean(record.get("Body")),
        "cycle": _clean(record.get("UprCycle")),
        "year": str(record.get("PublicationDate") or "")[:4],
        "recommending_state": _join(record.get("UprRecommendingCountry")) or None,
        "recommendation": _plain_text(record.get("Text")),
        "theme": _join(record.get("Themes")),
        "status": _join(record.get("UprPositions")),
        "annotation_type": _clean(record.get("AnnotationType")),
        "symbol": record.get("Symbol", ""),
    }


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
