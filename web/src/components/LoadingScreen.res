// Shown before the first round arrives: a spinner while connecting, or a
// retry notice once the initial load has failed (App auto-retries every 5s).
@react.component
let make = (~lang, ~error) => {
  let tr = I18n.strings(lang)
  <main className="app">
    <div className="loading-screen">
      {error == ""
        ? <>
            <div className="spinner" />
            <p> {React.string(tr.connecting)} </p>
          </>
        : <p className="error" role="alert"> {React.string(tr.serverWeak)} </p>}
    </div>
  </main>
}
