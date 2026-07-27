// The sign-in overlay: a backdrop plus a modal wrapping AuthForm. The parent
// owns whether it's shown and mounts this only while open.
@react.component
let make = (~lang, ~onClose, ~onSuccess) => {
  let tr = I18n.strings(lang)
  <div className="auth-overlay">
    <div className="menu-backdrop" onClick={_ => onClose()} />
    <div className="auth-modal" role="dialog">
      <button
        type_="button" className="ghost auth-close" ariaLabel={tr.close} onClick={_ => onClose()}>
        {React.string("×")}
      </button>
      <AuthForm lang onSuccess />
    </div>
  </div>
}
