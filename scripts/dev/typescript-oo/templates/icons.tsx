import * as React from "react";
import {css} from "emotion";

export type IconStyle = {
	color: string;
	width: number;
	height: number;
}

type Props = {
	iconStyle: IconStyle
	icon: string
}

class RenderIcon
	extends React.Component<Props> {
	render() {
		const iconStyle = css`
		 width: ${this.props.iconStyle.width}px;
		 height: ${this.props.iconStyle.height}px;
		 background: ${this.props.iconStyle.color};
		 -webkit-mask-image: url(${this.props.icon});
		 mask-image: url(${this.props.icon});
		 mask-size: cover;
		 display: inline-block;
		`;

		return <span className={iconStyle}/>;
	}
}


export type IconData = {
	ratio: number,
	value: string
}

export const iconsRenderer = (key: IconData, color?: string, width: number = 24) => {
	return <RenderIcon icon={key.value} iconStyle={{color: color || "#000000", height: width * key.ratio, width: width}}/>
};

ICONS_DECLARATION

export const ICONS = {
	ICONS_USAGE
};

export type IconsType = typeof ICONS