from pathlib import Path

import fitz  # PyMuPDF


SCREENSHOTS_DIR = Path("reports/screenshots")

PDF_FILES = [
    "executive_customer_health_dashboard.pdf",
    "customer_success_risk_queue.pdf",
]


def convert_first_page_to_png(pdf_path: Path, output_path: Path, zoom: float = 2.0) -> None:
    if not pdf_path.exists():
        raise FileNotFoundError(f"PDF not found: {pdf_path}")

    document = fitz.open(pdf_path)

    if document.page_count == 0:
        raise ValueError(f"PDF has no pages: {pdf_path}")

    page = document.load_page(0)
    matrix = fitz.Matrix(zoom, zoom)
    pixmap = page.get_pixmap(matrix=matrix, alpha=False)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    pixmap.save(output_path)

    document.close()


def main() -> None:
    for pdf_file in PDF_FILES:
        pdf_path = SCREENSHOTS_DIR / pdf_file
        output_path = SCREENSHOTS_DIR / pdf_file.replace(".pdf", ".png")

        convert_first_page_to_png(pdf_path, output_path)

        print(f"Converted: {pdf_path} -> {output_path}")


if __name__ == "__main__":
    main()