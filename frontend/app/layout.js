export const metadata = {
  title: "Resilient Study Platform",
  description: "Frontend for the resilient study platform"
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body style={{ margin: 0, fontFamily: "Arial, sans-serif", background: "#f7f9fc" }}>{children}</body>
    </html>
  );
}
