// @keepTs
// @ts-nocheck
import { LvLink } from '../domain/LvLink';
@Component
export declare struct lvHyperlinkComponent {
    @Prop
    text: string;
    @Prop
    uri: string;
    @Prop
    nLink: LvLink;
    @Prop
    fontSize: number | string;
    @Prop
    fontWeight: FontWeight;
    @Prop
    dialogController: CustomDialogController | null;
    build(): void;
}
@Builder
export default function lvHyperlinkBuilder(g114: string, h114: string, i114: LvLink, j114: number | string, k114: FontWeight, l114: CustomDialogController | null): void;
