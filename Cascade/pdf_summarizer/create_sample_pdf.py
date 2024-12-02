from fpdf import FPDF

def create_sample_pdf():
    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Arial", size=12)
    
    # Add title
    pdf.set_font("Arial", 'B', 16)
    pdf.cell(200, 10, txt="Artificial Intelligence in Healthcare: A Review", ln=1, align='C')
    
    # Add content
    pdf.set_font("Arial", size=12)
    content = """
    Abstract:
    This paper reviews the current state and future prospects of artificial intelligence (AI) in healthcare. Recent advances in machine learning, particularly deep learning, have shown promising results in medical diagnosis, treatment planning, and patient care management.

    Introduction:
    The integration of artificial intelligence in healthcare has witnessed significant growth over the past decade. Healthcare providers and researchers are increasingly leveraging AI technologies to improve patient outcomes, reduce costs, and enhance operational efficiency.

    Key Applications:
    1. Medical Imaging Analysis:
    AI systems have demonstrated remarkable accuracy in analyzing medical images, including X-rays, MRIs, and CT scans. Deep learning models can detect abnormalities and assist radiologists in making more accurate diagnoses.

    2. Clinical Decision Support:
    Machine learning algorithms can process vast amounts of patient data to provide evidence-based treatment recommendations and predict patient outcomes.

    3. Drug Discovery:
    AI accelerates the drug discovery process by analyzing biological data and predicting molecular properties, potentially reducing the time and cost of bringing new drugs to market.

    Challenges and Limitations:
    Despite its potential, AI in healthcare faces several challenges:
    - Data privacy and security concerns
    - Integration with existing healthcare systems
    - Regulatory compliance
    - Need for large, high-quality training datasets

    Future Directions:
    The future of AI in healthcare looks promising, with emerging applications in:
    - Personalized medicine
    - Remote patient monitoring
    - Automated administrative tasks
    - Predictive healthcare analytics

    Conclusion:
    While challenges remain, the continued development of AI technologies in healthcare shows great promise for improving patient care and medical research outcomes.
    """
    
    pdf.multi_cell(0, 10, txt=content)
    pdf.output("sample_research.pdf")

if __name__ == "__main__":
    create_sample_pdf()
