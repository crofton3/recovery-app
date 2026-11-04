import { Footer, Layout, Navbar } from 'nextra-theme-docs'
import { Head } from 'nextra/components'
import { getPageMap } from 'nextra/page-map'
import 'nextra-theme-docs/style.css'

export const metadata = {
  title: { default: 'Achilles docs', template: '%s | Achilles docs' },
  description: 'Setup and reference for Achilles, a free personal recovery tracker for iPhone.'
}

const navbar = <Navbar logo={<b>Achilles</b>} projectLink="https://github.com/crofton3/recovery-app" />
const footer = <Footer>MIT {new Date().getFullYear()} © Achilles. Personal project, not medical advice.</Footer>

export default async function RootLayout({ children }) {
  return (
    <html lang="en" dir="ltr" suppressHydrationWarning>
      <Head faviconGlyph="A" />
      <body>
        <Layout
          navbar={navbar}
          pageMap={await getPageMap()}
          docsRepositoryBase="https://github.com/crofton3/recovery-app/tree/main/docs"
          footer={footer}
        >
          {children}
        </Layout>
      </body>
    </html>
  )
}
