import { useEffect, useRef } from 'react'

import { useParams } from 'common'
import { ProjectLayoutWithAuth } from 'components/layouts/ProjectLayout/ProjectLayout'
import { useSelectedProject } from 'hooks'
import { useAppStateSnapshot } from 'state/app-state'
import type { NextPageWithLayout } from 'types'

const Home: NextPageWithLayout = () => {
  const project = useSelectedProject()

  const snap = useAppStateSnapshot()
  const { enableBranching } = useParams()

  const hasShownEnableBranchingModalRef = useRef(false)
  useEffect(() => {
    if (enableBranching && !hasShownEnableBranchingModalRef.current) {
      hasShownEnableBranchingModalRef.current = true
      snap.setShowEnableBranchingModal(true)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [enableBranching])

  const projectName =
    project?.ref !== 'default' && project?.name !== undefined
      ? project?.name
      : 'Welcome to Televolution'

  return (
    <div>
      <div className="mx-6">
        <iframe src="http://localhost:3001/status/services" title="Televolution Monitor" style={{ width: '100%', height: '1000px', border: 'none' }}></iframe>
      </div>
    </div>
  )
}

Home.getLayout = (page) => (
  <ProjectLayoutWithAuth>
    <main style={{ maxHeight: '100vh' }} className="flex-1 overflow-y-auto">
      {page}
    </main>
  </ProjectLayoutWithAuth>
)

export default Home
