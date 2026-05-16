import { type ReactNode, type MouseEventHandler } from "react";

type CommonProps = {
  children: ReactNode;
  className?: string;
  danger?: boolean;
};

type ButtonAsButton = CommonProps & {
  href?: undefined;
  onClick?: MouseEventHandler<HTMLButtonElement>;
  type?: "button" | "submit" | "reset";
  disabled?: boolean;
};

type ButtonAsLink = CommonProps & {
  href: string;
  external?: boolean;
};

export type ButtonProps = ButtonAsButton | ButtonAsLink;

export const Button = (props: ButtonProps) => {
  const className = ["cmd", props.danger && "danger", props.className]
    .filter(Boolean)
    .join(" ");
  const content = (
    <>
      {"[ "}
      {props.children}
      {" ]"}
    </>
  );

  if ("href" in props && props.href !== undefined) {
    const { href, external } = props;
    return (
      <a
        className={className}
        href={href}
        {...(external ? { target: "_blank", rel: "noreferrer" } : {})}
      >
        {content}
      </a>
    );
  }

  const { onClick, type = "button", disabled } = props;
  return (
    <button
      type={type}
      className={className}
      onClick={onClick}
      disabled={disabled}
    >
      {content}
    </button>
  );
};
